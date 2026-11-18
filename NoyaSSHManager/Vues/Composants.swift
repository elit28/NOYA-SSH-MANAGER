import NoyaCore
import SwiftUI

// MARK: - Boutons

/// Bouton principal turquoise (« Se connecter »).
struct StyleBoutonPrincipal: ButtonStyle {
    @Environment(\.isEnabled) private var actif

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.texteSurTurquoise)
            .padding(.horizontal, 20)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.turquoise.opacity(configuration.isPressed ? 0.8 : 1))
            )
            .opacity(actif ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Bouton secondaire discret.
struct StyleBoutonSecondaire: ButtonStyle {
    var hauteur: CGFloat = 30
    @Environment(\.isEnabled) private var actif

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(Theme.textePrincipal)
            .padding(.horizontal, hauteur > 34 ? 16 : 12)
            .frame(height: hauteur)
            .background(
                RoundedRectangle(cornerRadius: hauteur > 34 ? 10 : 8, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08))
            )
            .opacity(actif ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Badges

struct Badge: View {
    let texte: String
    var couleurTexte: Color = Theme.texteAttenue
    var couleurFond: Color = Color.white.opacity(0.06)

    var body: some View {
        Text(texte)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(couleurTexte)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(couleurFond))
    }
}

struct BadgeEnvironnement: View {
    let environnement: Environnement

    var body: some View {
        HStack(spacing: 5) {
            switch environnement {
            case .production:
                Circle().fill(Theme.ambre).frame(width: 6, height: 6)
                Text("Production")
            case .test:
                Circle().fill(Theme.bleu).frame(width: 6, height: 6)
                Text("Test")
            case .ancien:
                Image(systemName: "archivebox").font(.system(size: 10, weight: .semibold))
                Text("Ancien serveur")
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(couleurTexte)
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(couleurFond))
        .accessibilityElement(children: .combine)
    }

    private var couleurTexte: Color {
        switch environnement {
        case .production: Theme.ambreTexte
        case .test: Theme.bleu
        case .ancien: Theme.texteAttenue
        }
    }

    private var couleurFond: Color {
        switch environnement {
        case .production: Theme.ambre.opacity(0.14)
        case .test: Theme.bleu.opacity(0.12)
        case .ancien: Color.white.opacity(0.08)
        }
    }
}

// MARK: - Indicateurs de disponibilité

/// Petit indicateur de la barre latérale.
struct IndicateurDisponibilite: View {
    let disponibilite: Disponibilite
    @Environment(\.animationsActives) private var animationsActives

    var body: some View {
        Group {
            if disponibilite == .verification && animationsActives {
                ProgressView()
                    .controlSize(.mini)
            } else if case .accessible = disponibilite {
                pastille(pleine: true)
            } else if case .inaccessible = disponibilite {
                pastille(pleine: true)
            } else {
                pastille(pleine: false)
            }
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }

    private func pastille(pleine: Bool) -> some View {
        ZStack {
            if pleine {
                Circle().fill(disponibilite.couleur.opacity(0.18)).frame(width: 14, height: 14)
                Circle().fill(disponibilite.couleur).frame(width: 9, height: 9)
            } else {
                Circle().strokeBorder(disponibilite.couleur, lineWidth: 1.5).frame(width: 9, height: 9)
            }
        }
    }
}

/// Grande icône d'état de la fiche serveur.
struct IconeDisponibilite: View {
    let disponibilite: Disponibilite
    @Environment(\.animationsActives) private var animationsActives

    var body: some View {
        ZStack {
            Circle().fill(disponibilite.couleur.opacity(0.15))
            switch disponibilite {
            case .accessible:
                Image(systemName: "checkmark").font(.system(size: 17, weight: .bold))
            case .inaccessible:
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold))
            case .verification:
                if animationsActives {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold))
                }
            case .inconnue:
                Image(systemName: "questionmark").font(.system(size: 16, weight: .bold))
            case .nonVerifiable:
                Image(systemName: "arrow.triangle.branch").font(.system(size: 15, weight: .bold))
            }
        }
        .foregroundStyle(disponibilite.couleur)
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }
}

// MARK: - Champ de recherche

struct ChampRecherche: View {
    @Binding var texte: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.texteTertiaire)
                .accessibilityHidden(true)
            TextField("Rechercher", text: $texte, prompt: Text("Rechercher (⌘F)"))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(focus)
                .accessibilityLabel("Rechercher un serveur")
                .onExitCommand { texte = "" }
            if !texte.isEmpty {
                Button {
                    texte = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.texteTertiaire)
                }
                .buttonStyle(.plain)
                .help("Effacer la recherche")
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.fondChamp))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(focus.wrappedValue ? Theme.turquoise.opacity(0.6) : Color.white.opacity(0.06))
        )
    }
}

// MARK: - Divers

/// Ligne d'information avec icône, texte sur plusieurs lignes.
struct LigneInfo: View {
    let icone: String
    let texte: String
    var couleur: Color = Theme.texteSecondaire

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icone)
                .accessibilityHidden(true)
            Text(verbatim: texte)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
        .foregroundStyle(couleur)
    }
}

/// Notification flottante (« Commande copiée… »), masquée automatiquement.
struct NotificationFlottante: View {
    @Environment(ServeurStore.self) private var store
    @Environment(\.animationsActives) private var animationsActives

    var body: some View {
        ZStack {
            if let texte = store.notification {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.turquoise)
                    Text(verbatim: texte)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textePrincipal)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.fondNotification))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
                .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
                .padding(.bottom, 22)
                .transition(.opacity)
            }
        }
        .animation(animationsActives ? .easeOut(duration: 0.18) : nil, value: store.notification)
        .allowsHitTesting(false)
    }
}
