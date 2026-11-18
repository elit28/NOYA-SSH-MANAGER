import NoyaCore
import SwiftUI

/// Feuille d'import des hôtes définis dans `~/.ssh/config` (lecture seule).
struct ImportConfigSSH: View {
    struct Candidat: Identifiable {
        let alias: String
        var selectionne = true
        var details: EtatParametres?
        var id: String { alias }
    }

    @Environment(ServeurStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var candidats: [Candidat] = []
    @State private var dejaPresents = 0
    @State private var chargement = true
    @State private var groupe = ""
    @State private var environnement: Environnement = .production

    private var nombreSelectionnes: Int {
        candidats.filter(\.selectionne).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Importer depuis ~/.ssh/config")
                    .font(.system(size: 15, weight: .semibold))
                Text(verbatim: "Sélectionnez les hôtes à ajouter. Le fichier est seulement lu ; les hôtes génériques (avec * ou ?) sont ignorés.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.texteSecondaire)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if chargement {
                ProgressView("Lecture de la configuration…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if candidats.isEmpty {
                ContentUnavailableView {
                    Label("Aucun hôte à importer", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text(verbatim: dejaPresents > 0
                        ? "Tous les hôtes de votre configuration sont déjà dans la liste."
                        : "Aucune section Host utilisable n'a été trouvée dans ~/.ssh/config.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    Button("Tout sélectionner") {
                        for index in candidats.indices { candidats[index].selectionne = true }
                    }
                    Button("Tout désélectionner") {
                        for index in candidats.indices { candidats[index].selectionne = false }
                    }
                    Spacer()
                    Text(verbatim: "\(nombreSelectionnes) sur \(candidats.count) sélectionné\(nombreSelectionnes > 1 ? "s" : "")")
                        .foregroundStyle(Theme.texteSecondaire)
                }
                .controlSize(.small)

                List {
                    ForEach($candidats) { $candidat in
                        Toggle(isOn: $candidat.selectionne) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: candidat.alias)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                Text(verbatim: description(candidat.details))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.texteTertiaire)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .listStyle(.bordered(alternatesRowBackgrounds: false))
                .frame(minHeight: 180)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Groupe")
                            .gridColumnAlignment(.trailing)
                        TextField("Groupe", text: $groupe, prompt: Text("Ex. : Mes serveurs"))
                            .labelsHidden()
                    }
                    GridRow {
                        Text("Environnement")
                        Picker("Environnement", selection: $environnement) {
                            ForEach(Environnement.allCases) { valeur in
                                Text(verbatim: valeur.libelle).tag(valeur)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                .font(.system(size: 13))
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Annuler", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(nombreSelectionnes > 1 ? "Importer \(nombreSelectionnes) serveurs" : "Importer") {
                    let aliases = candidats.filter(\.selectionne).map(\.alias)
                    store.importer(aliases: aliases, groupe: groupe, environnement: environnement)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nombreSelectionnes == 0)
            }
        }
        .padding(20)
        .frame(width: 540, height: 580)
        .background(Theme.fondBarreLaterale)
        .task {
            await charger()
        }
    }

    private func description(_ details: EtatParametres?) -> String {
        switch details {
        case .charge(let parametres):
            let utilisateur = parametres.utilisateur.map { "\($0)@" } ?? ""
            return "\(utilisateur)\(parametres.nomHote):\(parametres.port)"
        case .erreur(let message):
            return message
        case .chargement, .none:
            return "Lecture des paramètres…"
        }
    }

    private func charger() async {
        let config = await ServeurStore.lireConfigSSH()
        let existants = store.aliasExistants
        let tous = config.aliasConcrets
        let nouveaux = tous.filter { !existants.contains($0.lowercased()) }
        dejaPresents = tous.count - nouveaux.count
        candidats = nouveaux.map { Candidat(alias: $0) }
        chargement = false

        await ServeurStore.lireParametres(nouveaux) { alias, etat in
            if let index = candidats.firstIndex(where: { $0.alias == alias }) {
                candidats[index].details = etat
            }
        }
    }
}
