import NoyaCore
import SwiftUI

/// Feuille d'ajout ou de modification d'un serveur.
struct FormulaireServeur: View {
    @Environment(ServeurStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let serveurExistant: Serveur?

    @State private var nom: String
    @State private var alias: String
    @State private var groupe: String
    @State private var environnement: Environnement
    @State private var notes: String
    @State private var apercu: EtatParametres?
    @State private var confirmerSuppression = false

    init(serveurExistant: Serveur?) {
        self.serveurExistant = serveurExistant
        _nom = State(initialValue: serveurExistant?.nom ?? "")
        _alias = State(initialValue: serveurExistant?.alias ?? "")
        _groupe = State(initialValue: serveurExistant?.groupe ?? "")
        _environnement = State(initialValue: serveurExistant?.environnement ?? .production)
        _notes = State(initialValue: serveurExistant?.notes ?? "")
    }

    private var estModification: Bool { serveurExistant != nil }

    private var aliasPropre: String {
        alias.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var erreurAlias: String? {
        guard !aliasPropre.isEmpty else { return nil }
        do {
            try ValidationAlias.valider(aliasPropre)
        } catch {
            return error.localizedDescription
        }
        let doublon = store.serveurs.contains {
            $0.id != serveurExistant?.id && $0.alias.lowercased() == aliasPropre.lowercased()
        }
        return doublon ? "Cet alias est déjà utilisé par un autre serveur de la liste." : nil
    }

    private var peutEnregistrer: Bool {
        !aliasPropre.isEmpty && erreurAlias == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(estModification ? "Modifier le serveur" : "Ajouter un serveur")
                    .font(.system(size: 15, weight: .semibold))
                Text(verbatim: "La connexion utilise uniquement l'alias SSH. L'adresse, l'utilisateur et la clé sont lus dans ~/.ssh/config.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.texteSecondaire)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Form {
                Section("Identification") {
                    TextField("Nom affiché", text: $nom, prompt: Text("Ex. : Serveur web de production"))
                    LabeledContent("Groupe") {
                        HStack(spacing: 6) {
                            TextField("Groupe", text: $groupe, prompt: Text("Ex. : Client A"))
                                .labelsHidden()
                            if !store.groupesExistants.isEmpty {
                                Menu {
                                    ForEach(store.groupesExistants, id: \.self) { nomGroupe in
                                        Button(nomGroupe) { groupe = nomGroupe }
                                    }
                                } label: {
                                    Image(systemName: "chevron.up.chevron.down")
                                }
                                .menuStyle(.button)
                                .buttonStyle(.borderless)
                                .menuIndicator(.hidden)
                                .fixedSize()
                                .help("Choisir un groupe existant")
                                .accessibilityLabel("Choisir un groupe existant")
                            }
                        }
                    }
                    Picker("Environnement", selection: $environnement) {
                        ForEach(Environnement.allCases) { valeur in
                            Text(verbatim: valeur.libelle).tag(valeur)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Alias SSH", text: $alias, prompt: Text("Ex. : web-prod"))
                        .font(Theme.policeMono)
                        .autocorrectionDisabled()
                    LabeledContent("Hôte") { valeurDetectee { $0.nomHote } }
                    LabeledContent("Utilisateur") { valeurDetectee { $0.utilisateur ?? "Utilisateur local" } }
                    LabeledContent("Port") { valeurDetectee { String($0.port) } }
                } header: {
                    Text("Connexion")
                } footer: {
                    messageAlias
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, prompt: Text("Facultatif"), axis: .vertical)
                        .lineLimit(2...5)
                        .labelsHidden()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            LigneInfo(
                icone: "lock",
                texte: "Aucun mot de passe ni clé privée n'est enregistré. Le fichier ~/.ssh/config n'est jamais modifié par l'application."
            )
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                if estModification {
                    Button("Supprimer…", role: .destructive) {
                        confirmerSuppression = true
                    }
                }
                Spacer()
                Button("Annuler", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(estModification ? "Enregistrer" : "Ajouter") {
                    enregistrer()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!peutEnregistrer)
            }
            .padding(20)
        }
        .frame(width: 540, height: 640)
        .background(Theme.fondBarreLaterale)
        .task(id: aliasPropre) {
            await chargerApercu()
        }
        .confirmationDialog(
            "Supprimer « \(serveurExistant?.nomAffiche ?? "") » ?",
            isPresented: $confirmerSuppression,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let serveurExistant { store.supprimer(serveurExistant) }
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(verbatim: "Le serveur est retiré de la liste de l'application. Votre fichier ~/.ssh/config n'est pas modifié.")
        }
    }

    @ViewBuilder
    private var messageAlias: some View {
        if let erreurAlias {
            LigneInfo(icone: "exclamationmark.circle", texte: erreurAlias, couleur: Theme.rougeTexte)
        } else if aliasPropre.isEmpty {
            LigneInfo(icone: "info.circle", texte: "Indiquez l'alias défini dans une section Host de ~/.ssh/config.")
        } else if !store.configSSH.definit(aliasPropre) {
            LigneInfo(
                icone: "exclamationmark.triangle",
                texte: "Aucune section Host ne définit « \(aliasPropre) » dans ~/.ssh/config : ssh se connectera directement à cet hôte.",
                couleur: Theme.ambreTexte
            )
        } else {
            LigneInfo(icone: "checkmark", texte: "Alias trouvé dans ~/.ssh/config.", couleur: Theme.vert)
        }
    }

    @ViewBuilder
    private func valeurDetectee(_ extraire: (ParametresEffectifs) -> String) -> some View {
        switch apercu {
        case .charge(let parametres):
            Text(verbatim: extraire(parametres))
                .font(Theme.policeMono)
                .foregroundStyle(Theme.texteAttenue)
                .textSelection(.enabled)
        case .chargement:
            ProgressView().controlSize(.small)
        case .erreur:
            Text("Illisible").foregroundStyle(Theme.ambreTexte)
        case .none:
            Text(verbatim: "—").foregroundStyle(Theme.texteTertiaire)
        }
    }

    /// Lit les paramètres de l'alias saisi (après une courte pause de frappe).
    private func chargerApercu() async {
        let aliasCourant = aliasPropre
        guard ValidationAlias.estValide(aliasCourant) else {
            apercu = nil
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(350))
        } catch {
            return
        }
        apercu = .chargement
        do {
            let parametres = try await LecteurParametres.lire(alias: aliasCourant)
            guard !Task.isCancelled else { return }
            apercu = .charge(parametres)
        } catch {
            guard !Task.isCancelled else { return }
            apercu = .erreur(error.localizedDescription)
        }
    }

    private func enregistrer() {
        guard peutEnregistrer else { return }
        var serveur = serveurExistant ?? Serveur(nom: "", alias: "")
        serveur.nom = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        serveur.alias = aliasPropre
        serveur.groupe = groupe.trimmingCharacters(in: .whitespacesAndNewlines)
        serveur.environnement = environnement
        serveur.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if estModification {
            store.mettreAJour(serveur)
        } else {
            store.ajouter(serveur)
        }
        dismiss()
    }
}
