import NoyaCore
import SwiftUI

/// Fenêtre « Réglages… » (⌘,).
struct VueReglages: View {
    var body: some View {
        TabView {
            ReglagesGeneraux()
                .tabItem { Label("Général", systemImage: "gearshape") }
            ReglagesTerminal()
                .tabItem { Label("Terminal", systemImage: "terminal") }
            ReglagesSurveillance()
                .tabItem { Label("Surveillance", systemImage: "waveform.path.ecg") }
            ReglagesConfidentialite()
                .tabItem { Label("Confidentialité", systemImage: "hand.raised") }
        }
        .frame(width: 580, height: 520)
        .modifier(AnimationsActives())
        .preferredColorScheme(.dark)
    }
}

struct ReglagesGeneraux: View {
    @Environment(ServeurStore.self) private var store
    @AppStorage(CleReglage.animations) private var animations = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Application de terminal") {
                    Text(verbatim: "Terminal.app")
                }
                LigneInfo(icone: "macwindow", texte: "Chaque connexion s'ouvre dans une nouvelle fenêtre Terminal, avec /usr/bin/ssh.")
            }

            Section {
                Toggle("Animations de l'interface", isOn: $animations)
                LigneInfo(
                    icone: "figure.walk.motion",
                    texte: "Toujours désactivées si « Réduire les animations » est actif dans les réglages d'accessibilité de macOS."
                )
            }

            Section("Liste des serveurs") {
                LabeledContent("Emplacement") {
                    Text(verbatim: cheminAbrege)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                HStack(spacing: 8) {
                    Button("Afficher dans le Finder") { store.afficherFichierDansFinder() }
                        .disabled(store.stockage == nil)
                    Spacer()
                    Button("Importer une liste…") { store.importerFichier() }
                    Button("Exporter la liste…") { store.exporterFichier() }
                        .disabled(store.serveurs.isEmpty)
                }
            }

            Section("Assistant IA local (macOS 27)") {
                LabeledContent("État") {
                    Text(verbatim: texteEtatAssistant)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if store.etatAssistant == .licenceNonAcceptee {
                    Button("Copier « \(AssistantFM.commandeLicence) »") {
                        store.copierTexte(AssistantFM.commandeLicence)
                    }
                }
                LigneInfo(
                    icone: "sparkles",
                    texte: "Ouvre « fm chat » dans Terminal (⌥⌘A) avec le modèle d’Apple exécuté sur ce Mac, jamais le Private Cloud Compute. Les conversations sont enregistrées par fm dans ~/.fm/sessions ; NOYA SSH Manager ne les lit pas."
                )
            }

            Section {
                LigneInfo(
                    icone: "power",
                    texte: "L'application se ferme entièrement avec sa dernière fenêtre : aucun processus ne reste en arrière-plan."
                )
            }
        }
        .formStyle(.grouped)
        .task {
            if store.assistantInstalle {
                await store.verifierAssistant()
            }
        }
    }

    private var texteEtatAssistant: String {
        if !store.assistantInstalle { return EtatAssistant.absent.description }
        return store.etatAssistant?.description ?? "Vérification…"
    }

    private var cheminAbrege: String {
        guard let chemin = store.stockage?.url.path else { return "Indisponible" }
        let maison = FileManager.default.homeDirectoryForCurrentUser.path
        return chemin.hasPrefix(maison) ? "~" + String(chemin.dropFirst(maison.count)) : chemin
    }
}

/// Couleur de fond des fenêtres Terminal selon l'environnement du serveur.
struct ReglagesTerminal: View {
    @AppStorage(CleReglage.fondSelonEnvironnement) private var actif = true
    @AppStorage(CleReglage.fond(.production)) private var fondProduction = CouleurFond.parDefaut(pour: .production).hex
    @AppStorage(CleReglage.fond(.test)) private var fondTest = CouleurFond.parDefaut(pour: .test).hex
    @AppStorage(CleReglage.fond(.ancien)) private var fondAncien = CouleurFond.parDefaut(pour: .ancien).hex

    var body: some View {
        Form {
            Section {
                Toggle("Couleur de fond selon l’environnement", isOn: $actif)
                LigneInfo(
                    icone: "info.circle",
                    texte: "Seul le fond de la fenêtre ouverte par NOYA SSH Manager change : votre profil Terminal (police, couleur du texte, curseur) et vos réglages ne sont jamais modifiés."
                )
            }

            Section("Couleurs") {
                ColorPicker("Production", selection: liaison($fondProduction, .production), supportsOpacity: false)
                ColorPicker("Test", selection: liaison($fondTest, .test), supportsOpacity: false)
                ColorPicker("Ancien serveur", selection: liaison($fondAncien, .ancien), supportsOpacity: false)
                Button("Rétablir les couleurs par défaut") {
                    fondProduction = CouleurFond.parDefaut(pour: .production).hex
                    fondTest = CouleurFond.parDefaut(pour: .test).hex
                    fondAncien = CouleurFond.parDefaut(pour: .ancien).hex
                }
            }
            .disabled(!actif)

            Section {
                LigneInfo(
                    icone: "eye",
                    texte: "Choisissez des fonds sombres si votre texte est clair. Le fond s’applique dès l’ouverture de la fenêtre, avant la connexion ; l’assistant IA garde le fond de votre profil."
                )
            }
        }
        .formStyle(.grouped)
    }

    private func liaison(_ texte: Binding<String>, _ environnement: Environnement) -> Binding<Color> {
        Binding(
            get: { Color(couleur: CouleurFond(hex: texte.wrappedValue) ?? CouleurFond.parDefaut(pour: environnement)) },
            set: { nouvelle in
                if let couleur = CouleurFond(couleur: nouvelle) {
                    texte.wrappedValue = couleur.hex
                }
            }
        )
    }
}

struct ReglagesSurveillance: View {
    @AppStorage(CleReglage.actualisationAuto) private var actualisationAuto = true
    @AppStorage(CleReglage.intervalle) private var intervalle = Reglages.intervalleParDefaut
    @AppStorage(CleReglage.delai) private var delai = Reglages.delaiParDefaut

    var body: some View {
        Form {
            Section {
                Toggle("Actualisation automatique", isOn: $actualisationAuto)
                Picker("Intervalle", selection: $intervalle) {
                    ForEach(Reglages.intervallesProposes, id: \.self) { valeur in
                        Text(verbatim: Reglages.libelleIntervalle(valeur)).tag(valeur)
                    }
                }
                .disabled(!actualisationAuto)
                Picker("Délai d'expiration", selection: $delai) {
                    ForEach(Reglages.delaisProposes, id: \.self) { valeur in
                        Text(verbatim: "\(valeur) secondes").tag(valeur)
                    }
                }
            } footer: {
                LigneInfo(icone: "macwindow", texte: "Uniquement lorsque la fenêtre principale est au premier plan.")
            }

            Section {
                LigneInfo(
                    icone: "info.circle",
                    texte: "Chaque vérification ouvre puis ferme une connexion TCP vers le port SSH, en parallèle pour tous les serveurs. Aucune authentification, aucune commande distante, aucune connexion maintenue."
                )
                LigneInfo(
                    icone: "exclamationmark.triangle",
                    texte: "Ces connexions apparaissent dans les journaux SSH des serveurs. Un pare-feu strict (par exemple fail2ban en mode agressif) peut les juger suspectes : augmentez l'intervalle si nécessaire.",
                    couleur: Theme.ambreTexte
                )
            }
        }
        .formStyle(.grouped)
    }
}

struct ReglagesConfidentialite: View {
    private let garanties: [(titre: String, detail: String)] = [
        ("Aucune télémétrie", "Aucune statistique d'usage n'est collectée."),
        ("Aucun compte requis", "L'application fonctionne entièrement en local."),
        ("Aucun envoi à un service tiers", "Seules les vérifications TCP sortent, vers vos propres serveurs."),
        ("Ni mot de passe ni clé privée", "Jamais lus, copiés ni enregistrés par l'application."),
        ("~/.ssh/config en lecture seule", "Paramètres lus avec « ssh -G alias », jamais modifiés."),
        ("Aucune option SSH ajoutée", "StrictHostKeyChecking et l'authentification restent ceux de votre configuration."),
        ("Assistant IA local facultatif", "Modèle d’Apple exécuté sur le Mac (macOS 27) ; l’app ne lit pas vos conversations."),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(garanties, id: \.titre) { garantie in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.vert)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: garantie.titre)
                            Text(verbatim: garantie.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.texteSecondaire)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
