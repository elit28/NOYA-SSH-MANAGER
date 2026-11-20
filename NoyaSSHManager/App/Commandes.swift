import AppKit
import NoyaCore
import SwiftUI

/// Menus et raccourcis clavier de l'application.
struct CommandesApplication: Commands {
    let store: ServeurStore

    /// Les commandes portant sur un serveur sont désactivées pendant
    /// l'affichage d'une feuille ou la saisie d'une recherche.
    private var serveurActif: Serveur? {
        guard store.feuille == nil, !store.rechercheActive else { return nil }
        return store.serveurSelectionne
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nouveau serveur…") {
                store.feuille = .ajout
            }
            .keyboardShortcut("n")
            .disabled(store.feuille != nil)

            Button("Importer depuis ~/.ssh/config…") {
                store.feuille = .importConfig
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(store.feuille != nil)

            Divider()

            Button("Importer une liste…") {
                store.importerFichier()
            }
            .disabled(store.feuille != nil)

            Button("Exporter la liste…") {
                store.exporterFichier()
            }
            .disabled(store.serveurs.isEmpty || store.feuille != nil)
        }

        CommandGroup(after: .textEditing) {
            Button("Rechercher un serveur") {
                store.demanderFocusRecherche()
            }
            .keyboardShortcut("f")
        }

        CommandMenu("Serveur") {
            Button("Se connecter") {
                if let serveur = serveurActif { store.connecter(serveur) }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(serveurActif == nil)

            Button("Copier la commande SSH") {
                if let serveur = serveurActif { store.copierCommande(serveur) }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(serveurActif == nil)

            Divider()

            Button("Modifier…") {
                if let serveur = serveurActif { store.feuille = .modification(serveur.id) }
            }
            .keyboardShortcut("e")
            .disabled(serveurActif == nil)

            Button("Supprimer…") {
                if let serveur = serveurActif { store.serveurASupprimer = serveur }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(serveurActif == nil)

            Divider()

            Button("Actualiser la disponibilité") {
                Task { await store.actualiser() }
            }
            .keyboardShortcut("r")
            .disabled(store.serveurs.isEmpty || store.verificationEnCours)

            Divider()

            Menu("Aller au serveur") {
                ForEach(Array(store.serveursOrdonnes.prefix(9).enumerated()), id: \.element.id) { index, serveur in
                    Button(serveur.nomAffiche) {
                        store.selection = serveur.id
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
            }
            .disabled(store.serveurs.isEmpty || store.feuille != nil)
        }

        CommandMenu("Assistant") {
            Button("Ouvrir l’assistant IA local") {
                store.ouvrirAssistant()
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(!store.assistantInstalle || store.ouvertureAssistantEnCours || store.feuille != nil)
        }

        CommandGroup(replacing: .help) {
            Button("Documentation de NOYA SSH Manager") {
                if let url = URL(string: "https://github.com/elit28/NOYA-SSH-MANAGER#readme") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
