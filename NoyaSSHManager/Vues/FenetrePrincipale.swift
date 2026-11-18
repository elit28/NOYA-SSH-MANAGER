import NoyaCore
import SwiftUI

/// Fenêtre principale : barre latérale des serveurs et fiche du serveur sélectionné.
struct FenetrePrincipale: View {
    @Environment(ServeurStore.self) private var store
    @Environment(\.controlActiveState) private var etatFenetre
    @AppStorage(CleReglage.actualisationAuto) private var actualisationAuto = true
    @AppStorage(CleReglage.intervalle) private var intervalle = Reglages.intervalleParDefaut

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            BarreLaterale()
                .navigationSplitViewColumnWidth(min: 230, ideal: 264, max: 360)
        } detail: {
            ZoneDetail()
        }
        .navigationTitle("NOYA SSH Manager")
        .navigationSubtitle(store.resume)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                BoutonActualiser()
                Button {
                    store.feuille = .ajout
                } label: {
                    Label("Ajouter un serveur", systemImage: "plus")
                }
                .help("Ajouter un serveur (⌘N)")
            }
        }
        .toolbarBackground(Theme.fondContenu, for: .windowToolbar)
        .sheet(item: $store.feuille) { feuille in
            switch feuille {
            case .ajout:
                FormulaireServeur(serveurExistant: nil)
            case .modification(let id):
                FormulaireServeur(serveurExistant: store.serveur(id))
            case .importConfig:
                ImportConfigSSH()
            }
        }
        .alert(
            store.erreur?.titre ?? "Erreur",
            isPresented: Binding(
                get: { store.erreur != nil },
                set: { if !$0 { store.erreur = nil } }
            ),
            presenting: store.erreur
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { erreur in
            Text(verbatim: erreur.message)
        }
        .confirmationDialog(
            "Supprimer « \(store.serveurASupprimer?.nomAffiche ?? "") » ?",
            isPresented: Binding(
                get: { store.serveurASupprimer != nil },
                set: { if !$0 { store.serveurASupprimer = nil } }
            ),
            titleVisibility: .visible,
            presenting: store.serveurASupprimer
        ) { serveur in
            Button("Supprimer", role: .destructive) {
                store.supprimer(serveur)
            }
            Button("Annuler", role: .cancel) {}
        } message: { _ in
            Text(verbatim: "Le serveur est retiré de la liste de l'application. Votre fichier ~/.ssh/config n'est pas modifié.")
        }
        .modifier(AnimationsActives())
        .preferredColorScheme(.dark)
        .task {
            await store.demarrer()
            store.definirFenetreActive(etatFenetre != .inactive)
        }
        .onChange(of: etatFenetre) { _, nouvelEtat in
            store.definirFenetreActive(nouvelEtat != .inactive)
        }
        .onChange(of: actualisationAuto) {
            store.redemarrerSurveillance()
        }
        .onChange(of: intervalle) {
            store.redemarrerSurveillance()
        }
        .onDisappear {
            store.arreterSurveillance()
        }
    }
}

/// Bouton « Actualiser » de la barre d'outils.
struct BoutonActualiser: View {
    @Environment(ServeurStore.self) private var store
    @Environment(\.animationsActives) private var animationsActives

    var body: some View {
        Button {
            Task { await store.actualiser() }
        } label: {
            if store.verificationEnCours && animationsActives {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Label("Actualiser", systemImage: "arrow.clockwise")
            }
        }
        .help("Actualiser la disponibilité (⌘R)")
        .disabled(store.verificationEnCours || store.serveurs.isEmpty)
        .accessibilityLabel(store.verificationEnCours ? "Vérification en cours" : "Actualiser")
    }
}

/// Zone de droite : fiche du serveur, ou état vide.
struct ZoneDetail: View {
    @Environment(ServeurStore.self) private var store

    var body: some View {
        Group {
            if store.serveurs.isEmpty {
                EtatVide()
            } else if let serveur = store.serveurSelectionne {
                FicheServeur(serveur: serveur)
            } else {
                ContentUnavailableView {
                    Label("Aucun serveur sélectionné", systemImage: "server.rack")
                } description: {
                    Text("Choisissez un serveur dans la barre latérale.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.fondContenu)
        .overlay(alignment: .bottom) {
            NotificationFlottante()
        }
    }
}

/// Premier lancement : aucune entrée locale.
struct EtatVide: View {
    @Environment(ServeurStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("Aucun serveur", systemImage: "server.rack")
        } description: {
            Text(verbatim: "Importez vos hôtes depuis ~/.ssh/config ou ajoutez un serveur manuellement. Aucun mot de passe ni clé privée n'est demandé.")
        } actions: {
            Button("Importer depuis ~/.ssh/config…") {
                store.feuille = .importConfig
            }
            .buttonStyle(StyleBoutonPrincipal())

            Button("Ajouter un serveur…") {
                store.feuille = .ajout
            }
            .buttonStyle(StyleBoutonSecondaire(hauteur: 40))
        }
    }
}
