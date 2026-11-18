import NoyaCore
import SwiftUI

/// Palette de l'application : bleu nuit, accents turquoise discrets.
enum Theme {
    static let turquoise = Color(hex: 0x3CCFC0)
    static let texteSurTurquoise = Color(hex: 0x04211E)

    static let fondContenu = Color(hex: 0x0F1522)
    static let fondBarreLaterale = Color(hex: 0x141B2A)
    static let fondCarte = Color(hex: 0x182131)
    static let fondChamp = Color(hex: 0x1F293B)
    static let fondNotification = Color(hex: 0x243045)
    static let separateur = Color.white.opacity(0.07)

    static let textePrincipal = Color(hex: 0xE8ECF1)
    static let texteSecondaire = Color(hex: 0x9AA4B2)
    static let texteTertiaire = Color(hex: 0x8C97A8)
    static let texteAttenue = Color(hex: 0xB7C0CC)

    static let vert = Color(hex: 0x30D158)
    static let rouge = Color(hex: 0xFF453A)
    static let rougeTexte = Color(hex: 0xFF7A70)
    static let ambre = Color(hex: 0xFFB547)
    static let ambreTexte = Color(hex: 0xFFC56B)
    static let bleu = Color(hex: 0x64D2FF)
    static let gris = Color(hex: 0xAAB4C3)

    static let policeMono = Font.system(size: 13, design: .monospaced)
}

extension Color {
    /// Couleur sRGB à partir d'un entier hexadécimal 0xRRGGBB.
    init(hex: UInt32, opacite: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacite
        )
    }
}

extension Disponibilite {
    /// Couleur de l'indicateur. La couleur n'est jamais le seul signal :
    /// un texte accompagne toujours l'état.
    var couleur: Color {
        switch self {
        case .accessible: Theme.vert
        case .inaccessible: Theme.rouge
        case .inconnue, .verification, .nonVerifiable: Theme.gris
        }
    }
}

/// Préférence d'animation : réglage de l'application et accessibilité macOS.
struct AnimationsActives: ViewModifier {
    @AppStorage(CleReglage.animations) private var animations = true
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    func body(content: Content) -> some View {
        content.environment(\.animationsActives, animations && !reduireAnimations)
    }
}

private struct CleAnimationsActives: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var animationsActives: Bool {
        get { self[CleAnimationsActives.self] }
        set { self[CleAnimationsActives.self] = newValue }
    }
}
