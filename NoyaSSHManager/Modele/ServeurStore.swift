import Accessibility
import AppKit
import Foundation
import NoyaCore
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// État des paramètres effectifs d'un alias (lus avec `ssh -G`).
enum EtatParametres: Equatable {
    case chargement
    case charge(ParametresEffectifs)
    case erreur(String)

    var parametres: ParametresEffectifs? {
        if case .charge(let parametres) = self { return parametres }
        return nil
    }
}

/// Feuilles (fenêtres modales) de la fenêtre principale.
enum Feuille: Identifiable, Equatable {
    case ajout
    case modification(Serveur.ID)
    case importConfig

    var id: String {
        switch self {
        case .ajout: "ajout"
        case .modification(let id): "modification-\(id.uuidString)"
        case .importConfig: "import"
        }
    }
}

/// Message d'erreur affiché dans une alerte.
struct MessageErreur: Identifiable, Equatable {
    let id = UUID()
    let titre: String
    let message: String
    /// Commande proposée à la copie (par exemple `sudo fm license`), jamais exécutée par l'app.
    var commandeACopier: String? = nil
}

/// Modèle principal : liste des serveurs, paramètres SSH, disponibilité et
/// surveillance périodique.
///
/// La surveillance ne tourne que lorsque la fenêtre principale est active.
/// Entre deux vérifications, la tâche dort (`Task.sleep`) sans consommer
/// de processeur ; elle est annulée dès que la fenêtre perd le focus ou se ferme.
@MainActor
@Observable
final class ServeurStore {
    // MARK: Données publiées

    private(set) var serveurs: [Serveur] = []
    var selection: Serveur.ID?
    var recherche = ""
    var feuille: Feuille?
    var serveurASupprimer: Serveur?
    var erreur: MessageErreur?
    var rechercheActive = false
    private(set) var notification: String?
    private(set) var disponibilites: [Serveur.ID: Disponibilite] = [:]
    private(set) var parametres: [Serveur.ID: EtatParametres] = [:]
    private(set) var configSSH = ConfigSSH()
    private(set) var derniereVerification: Date?
    private(set) var verificationEnCours = false
    /// Incrémenté pour demander le focus du champ de recherche (⌘F).
    private(set) var demandeFocusRecherche = 0

    let stockage: StockageServeurs?

    // MARK: Assistant IA local (fm, macOS 27)

    /// Présence de `/usr/bin/fm`, vérifiée une fois au lancement (simple test de fichier).
    let assistantInstalle = AssistantFM.estInstalle()
    /// Dernier état connu, affiché dans les réglages.
    private(set) var etatAssistant: EtatAssistant?
    private(set) var ouvertureAssistantEnCours = false

    // MARK: Tâches internes

    @ObservationIgnored private var tacheSurveillance: Task<Void, Never>?
    @ObservationIgnored private var tacheVerification: Task<Void, Never>?
    @ObservationIgnored private var tacheConfiguration: Task<Void, Never>?
    @ObservationIgnored private var tacheNotification: Task<Void, Never>?
    @ObservationIgnored private var demarre = false
    @ObservationIgnored private var fenetreActive = false

    /// Nombre maximal de processus `ssh -G` lancés simultanément.
    private static let processusSimultanes = 4

    init() {
        var erreurInitiale: MessageErreur?
        do {
            stockage = StockageServeurs(url: try StockageServeurs.emplacementParDefaut())
        } catch {
            stockage = nil
            erreurInitiale = MessageErreur(titre: "Stockage indisponible", message: error.localizedDescription)
        }
        erreur = erreurInitiale
        charger()
        LanceurTerminal.nettoyerAnciensScripts()
    }

    // MARK: - Données dérivées

    var serveurSelectionne: Serveur? {
        guard let selection else { return nil }
        return serveurs.first { $0.id == selection }
    }

    func serveur(_ id: Serveur.ID) -> Serveur? {
        serveurs.first { $0.id == id }
    }

    /// Groupes affichés dans la barre latérale, filtrés par la recherche.
    var groupesFiltres: [GroupeServeurs] {
        let filtres = serveurs.filter {
            Recherche.correspond($0, parametres: parametres[$0.id]?.parametres, requete: recherche)
        }
        return Recherche.grouper(filtres)
    }

    /// Tous les serveurs, dans l'ordre d'affichage (raccourcis ⌘1 à ⌘9).
    var serveursOrdonnes: [Serveur] {
        Recherche.grouper(serveurs).flatMap(\.serveurs)
    }

    func disponibilite(_ id: Serveur.ID) -> Disponibilite {
        disponibilites[id] ?? .inconnue
    }

    var aliasExistants: Set<String> {
        Set(serveurs.map { $0.alias.lowercased() })
    }

    var groupesExistants: [String] {
        let groupes = Set(serveurs.map { $0.groupe.trimmingCharacters(in: .whitespacesAndNewlines) })
        return groupes.filter { !$0.isEmpty }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Sous-titre de la fenêtre : « 4 serveurs · 3 accessibles ».
    var resume: String {
        let total = serveurs.count
        guard total > 0 else { return "Aucun serveur" }
        let pluriel = total > 1 ? "s" : ""
        guard derniereVerification != nil else { return "\(total) serveur\(pluriel)" }
        let accessibles = serveurs.filter { disponibilite($0.id).estAccessible }.count
        return "\(total) serveur\(pluriel) · \(accessibles) accessible\(accessibles > 1 ? "s" : "")"
    }

    var texteDernierControle: String {
        guard let derniereVerification else { return "Aucun contrôle pour l'instant" }
        return "Dernier contrôle : \(FormatHeure.texte(derniereVerification))"
    }

    func texteControleCourt(delai: Int) -> String {
        guard let derniereVerification else { return "Délai \(delai) s" }
        return "Contrôlé à \(FormatHeure.texte(derniereVerification)) · délai \(delai) s"
    }

    // MARK: - Persistance

    private func charger() {
        guard let stockage else { return }
        do {
            serveurs = try stockage.charger()
            selection = serveursOrdonnes.first?.id
        } catch {
            erreur = MessageErreur(titre: "Lecture impossible", message: error.localizedDescription)
        }
    }

    private func enregistrer() {
        guard let stockage else { return }
        do {
            try stockage.enregistrer(serveurs)
        } catch {
            erreur = MessageErreur(titre: "Enregistrement impossible", message: error.localizedDescription)
        }
    }

    // MARK: - Cycle de vie et surveillance

    /// Premier chargement, à l'ouverture de la fenêtre principale.
    func demarrer() async {
        guard !demarre else { return }
        demarre = true
        await rechargerConfiguration()
        await verifierTout()
    }

    /// Démarre ou suspend la surveillance selon l'état de la fenêtre.
    func definirFenetreActive(_ active: Bool) {
        fenetreActive = active
        guard demarre else { return }
        if active && Reglages.actualisationAuto {
            demarrerSurveillance()
        } else {
            arreterSurveillance()
        }
    }

    /// À appeler quand un réglage de surveillance change.
    func redemarrerSurveillance() {
        arreterSurveillance()
        definirFenetreActive(fenetreActive)
    }

    func arreterSurveillance() {
        tacheSurveillance?.cancel()
        tacheSurveillance = nil
    }

    private func demarrerSurveillance() {
        guard tacheSurveillance == nil else { return }
        tacheSurveillance = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let attente = Planification.delaiAvantProchaine(
                    derniere: self.derniereVerification,
                    maintenant: Date(),
                    intervalle: Reglages.intervalleSecondes
                )
                if attente > 0 {
                    do {
                        try await Task.sleep(for: .seconds(attente))
                    } catch {
                        return // Tâche annulée : fenêtre inactive ou fermée.
                    }
                    continue
                }
                await self.verifierTout()
            }
        }
    }

    /// Actualisation manuelle (⌘R) : relit la configuration puis vérifie tout.
    func actualiser() async {
        await rechargerConfiguration()
        await verifierTout()
    }

    /// Relit `~/.ssh/config` et les paramètres effectifs de chaque alias.
    func rechargerConfiguration() async {
        if let enCours = tacheConfiguration {
            await enCours.value
            return
        }
        let tache = Task { [weak self] in
            guard let self else { return }
            self.configSSH = await Self.lireConfigSSH()
            await self.resoudreParametres(pour: self.serveurs.map(\.id))
        }
        tacheConfiguration = tache
        await tache.value
        tacheConfiguration = nil
    }

    /// Vérifie tous les serveurs en parallèle. Si une vérification est déjà
    /// en cours, attend simplement sa fin.
    func verifierTout() async {
        if let enCours = tacheVerification {
            await enCours.value
            return
        }
        let tache = Task { [weak self] in
            guard let self else { return }
            self.verificationEnCours = true
            if let configuration = self.tacheConfiguration {
                await configuration.value
            }
            await self.verifier(self.serveurs.map(\.id))
            self.derniereVerification = Date()
            self.verificationEnCours = false
        }
        tacheVerification = tache
        await tache.value
        tacheVerification = nil
    }

    /// Vérifie les serveurs indiqués, en parallèle, avec le délai configuré.
    private func verifier(_ ids: [Serveur.ID]) async {
        let delai = Reglages.delaiSecondes
        let cibles = ids.map { ($0, parametres[$0]?.parametres) }
        for (id, _) in cibles where disponibilite(id) == .inconnue {
            disponibilites[id] = .verification
        }
        await withTaskGroup(of: (Serveur.ID, Disponibilite).self) { groupe in
            for (id, parametresServeur) in cibles {
                groupe.addTask {
                    let resultat = await Self.verifierPort(parametresServeur, delai: delai)
                    return (id, resultat)
                }
            }
            for await (id, resultat) in groupe where serveur(id) != nil {
                disponibilites[id] = resultat
            }
        }
    }

    nonisolated private static func verifierPort(_ parametres: ParametresEffectifs?, delai: Int) async -> Disponibilite {
        guard let parametres else {
            return .nonVerifiable(raison: "Paramètres SSH indisponibles : impossible de déterminer l'hôte à vérifier.")
        }
        if parametres.passeParUnRebond {
            return .nonVerifiable(
                raison: "Connexion via un serveur intermédiaire (ProxyJump ou ProxyCommand) : une vérification directe ne serait pas représentative."
            )
        }
        return await VerificateurTCP.verifier(hote: parametres.nomHote, port: parametres.port, delai: delai)
    }

    // MARK: - Configuration SSH

    /// Lit `~/.ssh/config` (et ses `Include`) hors du fil principal.
    nonisolated static func lireConfigSSH() async -> ConfigSSH {
        await Task.detached(priority: .userInitiated) {
            let maison = FileManager.default.homeDirectoryForCurrentUser
            let dossierSSH = maison.appendingPathComponent(".ssh", isDirectory: true)
            return ConfigSSH.charger(
                fichier: dossierSSH.appendingPathComponent("config"),
                dossierSSH: dossierSSH,
                dossierPersonnel: maison.path
            )
        }.value
    }

    private func resoudreParametres(pour ids: [Serveur.ID]) async {
        var idsParAlias: [String: [Serveur.ID]] = [:]
        for id in ids {
            guard let serveur = serveur(id) else { continue }
            idsParAlias[serveur.alias, default: []].append(id)
            if parametres[id] == nil { parametres[id] = .chargement }
        }
        await Self.lireParametres(Array(idsParAlias.keys)) { alias, etat in
            for id in idsParAlias[alias] ?? [] where serveur(id) != nil {
                parametres[id] = etat
            }
        }
    }

    /// Lit les paramètres de plusieurs alias avec `ssh -G`, quatre au plus en même temps.
    static func lireParametres(_ aliases: [String], recevoir: (String, EtatParametres) -> Void) async {
        guard !aliases.isEmpty else { return }
        await withTaskGroup(of: (String, EtatParametres).self) { groupe in
            var suivant = 0
            while suivant < min(processusSimultanes, aliases.count) {
                let alias = aliases[suivant]
                groupe.addTask { await Self.etatParametres(alias) }
                suivant += 1
            }
            for await (alias, etat) in groupe {
                recevoir(alias, etat)
                if suivant < aliases.count {
                    let alias = aliases[suivant]
                    groupe.addTask { await Self.etatParametres(alias) }
                    suivant += 1
                }
            }
        }
    }

    nonisolated private static func etatParametres(_ alias: String) async -> (String, EtatParametres) {
        do {
            return (alias, .charge(try await LecteurParametres.lire(alias: alias)))
        } catch {
            return (alias, .erreur(error.localizedDescription))
        }
    }

    // MARK: - Actions

    func connecter(_ serveur: Serveur) {
        Task {
            do {
                let commande = try CommandeSSH(alias: serveur.alias)
                let fond = Reglages.fondTerminal(pour: serveur.environnement)
                try await LanceurTerminal.ouvrir(script: commande.scriptTerminal(fond: fond))
                notifier("Ouverture de Terminal : \(commande.texteAffiche)")
            } catch {
                erreur = MessageErreur(titre: "Connexion impossible", message: error.localizedDescription)
            }
        }
    }

    /// Ouvre l'assistant IA local d'Apple (`fm chat`) dans Terminal, après un court diagnostic.
    /// Rien n'est lancé avec `sudo` ; le modèle Private Cloud Compute n'est jamais choisi.
    func ouvrirAssistant() {
        guard !ouvertureAssistantEnCours else { return }
        ouvertureAssistantEnCours = true
        Task {
            defer { ouvertureAssistantEnCours = false }
            let diagnostic = await AssistantFM.diagnostiquer()
            etatAssistant = diagnostic.etat
            switch diagnostic.etat {
            case .absent:
                erreur = MessageErreur(
                    titre: "Assistant IA local indisponible",
                    message: "L’assistant d’Apple (commande fm) est inclus dans macOS 27, sur les Mac Apple Silicon. Il n’est pas présent sur ce Mac."
                )
            case .licenceNonAcceptee:
                erreur = MessageErreur(
                    titre: "Conditions d’Apple à accepter",
                    message: "Avant la première utilisation, acceptez une seule fois les conditions d’Apple : dans Terminal, tapez « \(AssistantFM.commandeLicence) », saisissez votre mot de passe administrateur, puis répondez « y ». NOYA SSH Manager ne lance jamais de commande avec sudo.",
                    commandeACopier: AssistantFM.commandeLicence
                )
            case .modeleIndisponible(let raison):
                erreur = MessageErreur(titre: "Assistant IA local indisponible", message: raison)
            case .pret, .indetermine:
                do {
                    try await LanceurTerminal.ouvrir(script: AssistantFM.scriptTerminal(modeleLocalExplicite: diagnostic.modeleLocalExplicite))
                    notifier("Assistant IA local ouvert dans Terminal")
                } catch {
                    erreur = MessageErreur(titre: "Ouverture impossible", message: error.localizedDescription)
                }
            }
        }
    }

    /// Met à jour l'état de l'assistant (fenêtre Réglages), sans rien ouvrir.
    func verifierAssistant() async {
        etatAssistant = await AssistantFM.diagnostiquer().etat
    }

    func copierTexte(_ texte: String) {
        let pressePapiers = NSPasteboard.general
        pressePapiers.clearContents()
        pressePapiers.setString(texte, forType: .string)
        notifier("Copié : \(texte)")
    }

    func copierCommande(_ serveur: Serveur) {
        guard let commande = try? CommandeSSH(alias: serveur.alias) else { return }
        let pressePapiers = NSPasteboard.general
        pressePapiers.clearContents()
        pressePapiers.setString(commande.texteACopier, forType: .string)
        notifier("Commande copiée : \(commande.texteACopier)")
    }

    func demanderFocusRecherche() {
        demandeFocusRecherche += 1
    }

    func ajouter(_ serveur: Serveur) {
        serveurs.append(serveur)
        enregistrer()
        selection = serveur.id
        actualiserServeurs([serveur.id])
    }

    func mettreAJour(_ serveur: Serveur) {
        guard let index = serveurs.firstIndex(where: { $0.id == serveur.id }) else { return }
        let aliasModifie = serveurs[index].alias != serveur.alias
        serveurs[index] = serveur
        enregistrer()
        if aliasModifie {
            parametres[serveur.id] = nil
            disponibilites[serveur.id] = nil
            actualiserServeurs([serveur.id])
        }
    }

    func supprimer(_ serveur: Serveur) {
        serveurs.removeAll { $0.id == serveur.id }
        parametres[serveur.id] = nil
        disponibilites[serveur.id] = nil
        if selection == serveur.id {
            selection = serveursOrdonnes.first?.id
        }
        enregistrer()
        notifier("« \(serveur.nomAffiche) » a été retiré de la liste.")
    }

    /// Ajoute les alias choisis dans la feuille d'import `~/.ssh/config`.
    func importer(aliases: [String], groupe: String, environnement: Environnement) {
        let groupePropre = groupe.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidats = aliases.map {
            Serveur(nom: $0, alias: $0, groupe: groupePropre, environnement: environnement)
        }
        appliquerImport(candidats)
    }

    func importerFichier() {
        let panneau = NSOpenPanel()
        panneau.title = "Importer une liste de serveurs"
        panneau.prompt = "Importer"
        panneau.message = "Choisissez un fichier JSON exporté par NOYA SSH Manager."
        panneau.allowedContentTypes = [.json]
        panneau.allowsMultipleSelection = false
        panneau.canChooseDirectories = false
        guard panneau.runModal() == .OK, let url = panneau.url else { return }
        do {
            let donnees = try Data(contentsOf: url)
            appliquerImport(try StockageServeurs.decoder(donnees))
        } catch {
            erreur = MessageErreur(titre: "Import impossible", message: error.localizedDescription)
        }
    }

    func exporterFichier() {
        let panneau = NSSavePanel()
        panneau.title = "Exporter la liste des serveurs"
        panneau.prompt = "Exporter"
        panneau.message = "Le fichier contient les noms, alias, groupes et notes. Aucun secret."
        panneau.nameFieldStringValue = "serveurs.json"
        panneau.allowedContentTypes = [.json]
        guard panneau.runModal() == .OK, let url = panneau.url else { return }
        do {
            try StockageServeurs.encoder(serveurs).write(to: url, options: .atomic)
            notifier("Liste exportée : \(url.lastPathComponent)")
        } catch {
            erreur = MessageErreur(titre: "Export impossible", message: error.localizedDescription)
        }
    }

    func afficherFichierDansFinder() {
        guard let url = stockage?.url else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let dossier = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
            NSWorkspace.shared.open(dossier)
        }
    }

    private func appliquerImport(_ candidats: [Serveur]) {
        let resultat = Fusion.importer(candidats, dans: serveurs)
        if !resultat.ajoutes.isEmpty {
            serveurs.append(contentsOf: resultat.ajoutes)
            enregistrer()
            if selection == nil { selection = serveursOrdonnes.first?.id }
            actualiserServeurs(resultat.ajoutes.map(\.id))
        }
        notifier("Import : \(resultat.resume)")
    }

    /// Lit les paramètres puis vérifie les serveurs indiqués (après un ajout ou une modification).
    private func actualiserServeurs(_ ids: [Serveur.ID]) {
        Task {
            await resoudreParametres(pour: ids)
            await verifier(ids)
        }
    }

    private func notifier(_ texte: String) {
        notification = texte
        AccessibilityNotification.Announcement(texte).post()
        tacheNotification?.cancel()
        tacheNotification = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            self?.notification = nil
        }
    }
}
