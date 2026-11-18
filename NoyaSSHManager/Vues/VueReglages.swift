import NoyaCore
import SwiftUI

/// Fenêtre « Réglages… » (⌘,).
struct VueReglages: View {
    var body: some View {
        TabView {
            ReglagesGeneraux()
                .tabItem { Label("Général", systemImage: "gearshape") }
            ReglagesSurveillance()
                .tabItem { Label("Surveillance", systemImage: "waveform.path.ecg") }
            ReglagesConfidentialite()
                .tabItem { Label("Confidentialité", systemImage: "hand.raised") }
        }
        .frame(width: 580, height: 440)
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

            Section {
                LigneInfo(
                    icone: "power",
                    texte: "L'application se ferme entièrement avec sa dernière fenêtre : aucun processus ne reste en arrière-plan."
                )
            }
        }
        .formStyle(.grouped)
    }

    private var cheminAbrege: String {
        guard let chemin = store.stockage?.url.path else { return "Indisponible" }
        let maison = FileManager.default.homeDirectoryForCurrentUser.path
        return chemin.hasPrefix(maison) ? "~" + chemin.dropFirst(maison.count) : chemin
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
