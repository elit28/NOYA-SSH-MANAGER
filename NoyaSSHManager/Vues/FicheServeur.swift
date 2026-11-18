import NoyaCore
import SwiftUI

/// Fiche du serveur sélectionné.
struct FicheServeur: View {
    @Environment(ServeurStore.self) private var store
    let serveur: Serveur

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                EnTeteServeur(serveur: serveur)
                ActionsConnexion(serveur: serveur)
                CarteDisponibilite(
                    disponibilite: store.disponibilite(serveur.id),
                    parametres: store.parametres[serveur.id]?.parametres
                )
                SectionParametres(
                    serveur: serveur,
                    etat: store.parametres[serveur.id],
                    aliasDefini: store.configSSH.definit(serveur.alias)
                )
                if !serveur.notes.isEmpty {
                    SectionNotes(notes: serveur.notes)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// En-tête : icône, nom, badges et actions secondaires.
struct EnTeteServeur: View {
    @Environment(ServeurStore.self) private var store
    let serveur: Serveur

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 26))
                .foregroundStyle(Theme.turquoise)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.turquoise.opacity(0.15))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: serveur.nomAffiche)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.textePrincipal)
                    .lineLimit(2)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    BadgeEnvironnement(environnement: serveur.environnement)
                    Badge(texte: "Groupe : \(serveur.groupeAffiche)")
                }
            }

            Spacer(minLength: 12)

            Button {
                store.feuille = .modification(serveur.id)
            } label: {
                Label("Modifier", systemImage: "pencil")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(StyleBoutonSecondaire(hauteur: 30))
            .help("Modifier (⌘E)")

            Menu {
                Button("Copier la commande SSH") { store.copierCommande(serveur) }
                Divider()
                Button("Supprimer…", role: .destructive) { store.serveurASupprimer = serveur }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Plus d'actions")
            .accessibilityLabel("Plus d'actions")
        }
    }
}

/// Bouton principal « Se connecter » et commande exécutée.
struct ActionsConnexion: View {
    @Environment(ServeurStore.self) private var store
    let serveur: Serveur

    var body: some View {
        let commande = try? CommandeSSH(alias: serveur.alias)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    store.connecter(serveur)
                } label: {
                    Label("Se connecter", systemImage: "terminal")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(StyleBoutonPrincipal())
                .disabled(commande == nil)
                .help("Ouvrir une session SSH dans Terminal (⌘↩)")

                Button {
                    store.copierCommande(serveur)
                } label: {
                    Label("Copier la commande", systemImage: "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(StyleBoutonSecondaire(hauteur: 40))
                .disabled(commande == nil)
                .help("Copier « ssh \(serveur.alias) » (⇧⌘C)")

                Text("⌘↩ pour se connecter")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.texteTertiaire)
                    .padding(.leading, 4)
            }

            if let commande {
                HStack(spacing: 8) {
                    Text("Exécute")
                    Text(verbatim: commande.texteAffiche)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.textePrincipal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.fondChamp))
                        .textSelection(.enabled)
                    Text("dans une nouvelle fenêtre Terminal. Authentification et empreinte gérées par OpenSSH.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.texteTertiaire)
            } else {
                LigneInfo(
                    icone: "exclamationmark.triangle",
                    texte: "Alias invalide : connexion impossible. Modifiez ce serveur pour corriger l'alias.",
                    couleur: Theme.rougeTexte
                )
            }
        }
    }
}

/// Carte de disponibilité du port SSH.
struct CarteDisponibilite: View {
    @Environment(ServeurStore.self) private var store
    @AppStorage(CleReglage.delai) private var delai = Reglages.delaiParDefaut
    let disponibilite: Disponibilite
    let parametres: ParametresEffectifs?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconeDisponibilite(disponibilite: disponibilite)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: disponibilite.titre)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(couleurTitre)
                    Text(verbatim: detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.texteSecondaire)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Latence TCP")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.texteTertiaire)
                    Text(verbatim: latence)
                        .font(.system(size: 22, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textePrincipal)
                }
            }

            Rectangle().fill(Theme.separateur).frame(height: 1)

            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
                Text("Un port SSH ouvert ne garantit pas que la connexion réussira : la clé, l'utilisateur et l'empreinte du serveur ne sont vérifiés qu'au moment de se connecter.")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(verbatim: store.texteControleCourt(delai: delai))
                    .monospacedDigit()
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.texteSecondaire)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.fondCarte))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.separateur))
        .accessibilityElement(children: .combine)
    }

    private var couleurTitre: Color {
        if case .inaccessible = disponibilite { return Theme.rougeTexte }
        return Theme.textePrincipal
    }

    private var latence: String {
        switch disponibilite {
        case .accessible(let duree): FormatLatence.texte(duree)
        case .verification: "…"
        default: "—"
        }
    }

    private var cible: String {
        guard let parametres else { return "l'hôte" }
        let hote = parametres.nomHote.contains(":") ? "[\(parametres.nomHote)]" : parametres.nomHote
        return "\(hote):\(parametres.port)"
    }

    private var detail: String {
        switch disponibilite {
        case .inconnue:
            "Aucune vérification effectuée pour l'instant."
        case .verification:
            "Tentative de connexion TCP vers \(cible) (\(delai) s maximum)."
        case .accessible:
            "Connexion TCP établie vers \(cible), puis fermée aussitôt."
        case .inaccessible(let raison):
            "\(raison) Cible : \(cible)."
        case .nonVerifiable(let raison):
            raison
        }
    }
}

/// Paramètres effectifs lus avec `ssh -G`.
struct SectionParametres: View {
    let serveur: Serveur
    let etat: EtatParametres?
    let aliasDefini: Bool

    private let colonnes = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Paramètres de connexion")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textePrincipal)
                Spacer()
                Text(verbatim: "Lus dans ~/.ssh/config avec ssh -G · lecture seule")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.texteTertiaire)
            }

            LazyVGrid(columns: colonnes, spacing: 1) {
                CelluleParametre(titre: "Alias SSH", valeur: serveur.alias, couleur: Theme.turquoise)
                CelluleParametre(titre: "Hôte", valeur: valeur { $0.nomHote })
                CelluleParametre(titre: "Utilisateur", valeur: valeur { $0.utilisateur ?? "Utilisateur local" })
                CelluleParametre(titre: "Port", valeur: valeur { String($0.port) })
                CelluleParametre(
                    titre: "Clé d'identité",
                    valeur: valeur { $0.descriptionCles },
                    monospace: !(parametres?.clesConfigurees.isEmpty ?? true)
                )
                if let parametres, parametres.passeParUnRebond {
                    CelluleParametre(titre: "Rebond", valeur: parametres.proxyJump ?? "ProxyCommand")
                } else {
                    CelluleParametre(titre: "Empreinte du serveur", valeur: "Vérifiée par OpenSSH", monospace: false)
                }
            }
            .background(Theme.separateur)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.separateur))

            if case .erreur(let message) = etat {
                LigneInfo(icone: "exclamationmark.triangle", texte: message, couleur: Theme.ambreTexte)
            }
            if !aliasDefini {
                LigneInfo(
                    icone: "exclamationmark.triangle",
                    texte: "Aucune section Host ne définit « \(serveur.alias) » dans ~/.ssh/config : ssh se connectera directement à l'hôte « \(serveur.alias) ».",
                    couleur: Theme.ambreTexte
                )
            }
        }
    }

    private var parametres: ParametresEffectifs? { etat?.parametres }

    private func valeur(_ extraire: (ParametresEffectifs) -> String) -> String {
        switch etat {
        case .charge(let parametres): extraire(parametres)
        case .chargement: "Lecture…"
        case .erreur, .none: "—"
        }
    }
}

struct CelluleParametre: View {
    let titre: String
    let valeur: String
    var monospace = true
    var couleur: Color = Theme.textePrincipal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: titre)
                .font(.system(size: 11))
                .foregroundStyle(Theme.texteTertiaire)
            Text(verbatim: valeur)
                .font(monospace ? Theme.policeMono : .system(size: 13))
                .foregroundStyle(couleur)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(valeur)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.fondCarte)
        .accessibilityElement(children: .combine)
    }
}

struct SectionNotes: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textePrincipal)
            Text(verbatim: notes)
                .font(.system(size: 13))
                .foregroundStyle(Theme.texteSecondaire)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.fondCarte))
        }
    }
}
