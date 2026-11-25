import Foundation

/// État de l'assistant IA local d'Apple (`fm`, macOS 27).
public enum EtatAssistant: Equatable, Sendable {
    /// `/usr/bin/fm` absent : macOS antérieur à la version 27, ou Mac non pris en charge.
    case absent
    /// Conditions d'utilisation d'Apple non acceptées (`sudo fm license`, une seule fois).
    case licenceNonAcceptee
    /// Modèle présent mais pas utilisable pour l'instant (téléchargement en cours, Apple Intelligence…).
    case modeleIndisponible(raison: String)
    /// Prêt : le modèle sur le Mac répond.
    case pret
    /// État non déterminé (format de sortie inattendu) : `fm` affichera lui-même ses messages.
    case indetermine

    /// Texte affiché dans les réglages.
    public var description: String {
        switch self {
        case .absent:
            "Non disponible : nécessite macOS 27 sur un Mac Apple Silicon."
        case .licenceNonAcceptee:
            "Conditions d’Apple à accepter une seule fois dans Terminal : sudo fm license"
        case .modeleIndisponible(let raison):
            raison
        case .pret:
            "Prêt : modèle d’Apple exécuté sur ce Mac."
        case .indetermine:
            "État non déterminé : l’assistant affichera lui-même ses éventuels messages."
        }
    }
}

/// Raccourci vers l'assistant IA local d'Apple, `fm` (Foundation Models, macOS 27).
///
/// NOYA SSH Manager n'interroge pas le modèle lui-même : il ouvre une session
/// interactive `fm chat` dans Terminal, avec le modèle exécuté sur le Mac.
/// Il ne lance jamais `sudo` et ne choisit jamais le modèle Private Cloud Compute.
public enum AssistantFM {
    public static let executable = "/usr/bin/fm"
    public static let commandeLicence = "sudo fm license"

    /// Consignes données au modèle (courtes : la fenêtre de contexte est d'environ 4 000 jetons).
    public static let consignes = """
    Tu es l’assistant d’administration système de NOYA SSH Manager. Réponds en français, \
    de façon claire et concise. Aide à comprendre les commandes Linux et SSH, la configuration \
    ~/.ssh/config et les messages d’erreur. Ne demande jamais de mot de passe ni de clé privée. \
    Avant de proposer une commande risquée (suppression, droits, pare-feu, redémarrage), \
    explique le risque et propose une vérification ou une sauvegarde.
    """

    /// Présence de l'outil sur ce Mac.
    public static func estInstalle(executable: String = AssistantFM.executable) -> Bool {
        FileManager.default.isExecutableFile(atPath: executable)
    }

    /// Script ouvert par Terminal : se supprime, nomme la fenêtre, lance `fm chat`.
    /// `modeleLocalExplicite` ajoute `--model system`, qui garantit le modèle exécuté sur le Mac
    /// même si `fm config` désigne un autre fournisseur par défaut.
    public static func scriptTerminal(modeleLocalExplicite: Bool, executable: String = AssistantFM.executable) -> String {
        var arguments = [Shell.citer(executable), "chat"]
        if modeleLocalExplicite {
            arguments += ["--model", Shell.citer("system")]
        }
        arguments += ["--instructions", Shell.citer(consignes)]
        return """
        #!/bin/sh
        # Fichier temporaire créé par NOYA SSH Manager. Il se supprime lui-même.
        rm -f -- "$0"
        \(SequencesTerminal.effacer)
        printf '\\033]0;%s\\007' \(Shell.citer("Assistant IA local"))
        exec \(arguments.joined(separator: " "))

        """
    }

    // MARK: - Analyse des sorties de fm

    /// Code de sortie signalé par plusieurs tests quand les conditions ne sont pas acceptées.
    static let codeLicenceNonAcceptee: Int32 = 69

    /// `fm license --status` : vrai si acceptée, faux si refusée, nil si indéterminé.
    public static func licenceAcceptee(sortie: String, codeSortie: Int32) -> Bool? {
        let texte = sortie.lowercased()
        if codeSortie == codeLicenceNonAcceptee
            || texte.contains("not agreed")
            || texte.contains("have not agreed") {
            return false
        }
        if texte.contains("agreed") { return true }
        return nil
    }

    /// `fm available` : « System model available » ou « System model unavailable: raison ».
    public static func disponibilite(sortie: String) -> EtatAssistant {
        let lignes = sortie.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        for ligne in lignes {
            let minuscules = ligne.lowercased()
            if let deuxPoints = ligne.firstIndex(of: ":"), minuscules.contains("unavailable") {
                let raison = ligne[ligne.index(after: deuxPoints)...].trimmingCharacters(in: .whitespaces)
                return .modeleIndisponible(raison: messageRaison(raison))
            }
            if minuscules.contains("unavailable") {
                return .modeleIndisponible(raison: messageRaison(""))
            }
            if minuscules.contains("available") {
                return .pret
            }
        }
        return .indetermine
    }

    /// Vrai si l'aide de `fm chat` mentionne l'option `--model`.
    public static func chatAccepteModele(aide: String) -> Bool {
        aide.contains("--model")
    }

    /// Traduction des raisons connues d'indisponibilité.
    static func messageRaison(_ raison: String) -> String {
        switch raison {
        case "modelNotReady":
            "Le modèle d’Apple n’est pas encore prêt (téléchargement en cours par macOS). Réessayez plus tard."
        case "appleIntelligenceNotEnabled":
            "Apple Intelligence n’est pas disponible sur ce Mac (région, langue de Siri ou réglages)."
        case "deviceNotEligible":
            "Ce Mac ne prend pas en charge Apple Intelligence."
        case "":
            "Le modèle d’Apple n’est pas disponible pour l’instant."
        default:
            "Le modèle d’Apple n’est pas disponible (\(raison))."
        }
    }

    // MARK: - Diagnostic complet

    /// Résultat d'un diagnostic : état et prise en charge de `--model` par `fm chat`.
    public struct Diagnostic: Equatable, Sendable {
        public var etat: EtatAssistant
        public var modeleLocalExplicite: Bool
    }

    /// Lance au plus trois courtes commandes `fm` (licence, disponibilité, aide de `fm chat`),
    /// uniquement sur action de l'utilisateur. N'utilise jamais `sudo`.
    public static func diagnostiquer(
        executable: String = AssistantFM.executable,
        delai: Duration = .seconds(5)
    ) async -> Diagnostic {
        guard estInstalle(executable: executable) else {
            return Diagnostic(etat: .absent, modeleLocalExplicite: false)
        }

        if let licence = try? await ExecuteurProcessus.executer(executable, arguments: ["license", "--status"], delai: delai),
           licenceAcceptee(sortie: licence.sortie + licence.erreurs, codeSortie: licence.codeSortie) == false {
            return Diagnostic(etat: .licenceNonAcceptee, modeleLocalExplicite: false)
        }

        var etat = EtatAssistant.indetermine
        if let dispo = try? await ExecuteurProcessus.executer(executable, arguments: ["available"], delai: delai) {
            if dispo.codeSortie == codeLicenceNonAcceptee {
                return Diagnostic(etat: .licenceNonAcceptee, modeleLocalExplicite: false)
            }
            etat = disponibilite(sortie: dispo.sortie + "\n" + dispo.erreurs)
        }

        var explicite = false
        if let aide = try? await ExecuteurProcessus.executer(executable, arguments: ["chat", "--help"], delai: delai) {
            explicite = chatAccepteModele(aide: aide.sortie + aide.erreurs)
        }
        return Diagnostic(etat: etat, modeleLocalExplicite: explicite)
    }
}
