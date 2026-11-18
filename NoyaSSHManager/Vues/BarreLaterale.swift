import NoyaCore
import SwiftUI

/// Barre latérale : recherche, serveurs regroupés, état de la surveillance.
struct BarreLaterale: View {
    @Environment(ServeurStore.self) private var store
    @FocusState private var rechercheFocalisee: Bool

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            ChampRecherche(texte: $store.recherche, focus: $rechercheFocalisee)
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 6)

            List(selection: $store.selection) {
                ForEach(store.groupesFiltres) { groupe in
                    Section {
                        ForEach(groupe.serveurs) { serveur in
                            LigneServeur(serveur: serveur, disponibilite: store.disponibilite(serveur.id))
                                .tag(serveur.id)
                                .contextMenu {
                                    MenuContextuelServeur(serveur: serveur)
                                }
                        }
                    } header: {
                        Text(verbatim: groupe.nom)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .onDeleteCommand {
                if let serveur = store.serveurSelectionne {
                    store.serveurASupprimer = serveur
                }
            }
            .overlay {
                if !store.serveurs.isEmpty && store.groupesFiltres.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun résultat", systemImage: "magnifyingglass")
                    } description: {
                        Text(verbatim: "Aucun serveur ne correspond à « \(store.recherche) ».")
                    }
                } else if store.serveurs.isEmpty {
                    Text("Aucun serveur")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.texteTertiaire)
                }
            }

            PiedBarreLaterale()
        }
        .background(Theme.fondBarreLaterale)
        .onChange(of: store.demandeFocusRecherche) {
            rechercheFocalisee = true
        }
        .onChange(of: rechercheFocalisee) { _, focalisee in
            store.rechercheActive = focalisee
        }
    }
}

/// Une ligne de la barre latérale.
struct LigneServeur: View {
    let serveur: Serveur
    let disponibilite: Disponibilite

    var body: some View {
        HStack(spacing: 10) {
            IndicateurDisponibilite(disponibilite: disponibilite)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(verbatim: serveur.nomAffiche)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(serveur.environnement == .ancien ? Theme.texteAttenue : Theme.textePrincipal)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if serveur.environnement == .ancien {
                        Image(systemName: "archivebox")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.texteSecondaire)
                            .accessibilityLabel("Ancien serveur")
                    }
                }
                HStack(spacing: 6) {
                    Text(verbatim: serveur.alias)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.texteTertiaire)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(verbatim: disponibilite.libelleCourt)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(couleurLibelle)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var couleurLibelle: Color {
        if case .inaccessible = disponibilite { return Theme.rougeTexte }
        return Theme.texteTertiaire
    }
}

/// Menu contextuel d'un serveur (clic droit).
struct MenuContextuelServeur: View {
    @Environment(ServeurStore.self) private var store
    let serveur: Serveur

    var body: some View {
        Button("Se connecter") { store.connecter(serveur) }
        Button("Copier la commande SSH") { store.copierCommande(serveur) }
        Divider()
        Button("Modifier…") { store.feuille = .modification(serveur.id) }
        Button("Supprimer…", role: .destructive) { store.serveurASupprimer = serveur }
    }
}

/// Bas de la barre latérale : état de la surveillance et dernier contrôle.
struct PiedBarreLaterale: View {
    @Environment(ServeurStore.self) private var store
    @AppStorage(CleReglage.actualisationAuto) private var actualisationAuto = true
    @AppStorage(CleReglage.intervalle) private var intervalle = Reglages.intervalleParDefaut

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Circle()
                    .fill(actualisationAuto ? Theme.turquoise : Theme.gris)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(verbatim: actualisationAuto
                    ? "Surveillance active · \(Reglages.libelleIntervalleCourt(intervalle))"
                    : "Actualisation automatique désactivée")
            }
            Text(verbatim: store.texteDernierControle)
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.texteTertiaire)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.separateur).frame(height: 1)
        }
    }
}
