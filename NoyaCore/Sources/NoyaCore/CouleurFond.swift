import Foundation

/// Couleur de fond d'une fenêtre Terminal, au format « #RRGGBB », validée.
///
/// La couleur est appliquée par la séquence d'échappement OSC 11, que
/// Terminal.app accepte : seule la fenêtre ouverte change, jamais le profil
/// ni les réglages de Terminal.
public struct CouleurFond: Equatable, Hashable, Sendable, Codable {
    /// Toujours « # » suivi de six chiffres hexadécimaux en majuscules.
    public let hex: String

    /// Nil si le texte n'est pas exactement « #RRGGBB » (protection contre toute injection).
    public init?(hex texte: String) {
        let propre = texte.trimmingCharacters(in: .whitespaces)
        guard propre.count == 7, propre.first == "#" else { return nil }
        let chiffres = propre.dropFirst()
        guard chiffres.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        hex = "#" + chiffres.uppercased()
    }

    /// Composantes rouge, vert, bleu entre 0 et 1.
    public var composantes: (rouge: Double, vert: Double, bleu: Double) {
        let valeur = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return (
            Double((valeur >> 16) & 0xFF) / 255,
            Double((valeur >> 8) & 0xFF) / 255,
            Double(valeur & 0xFF) / 255
        )
    }

    /// Construit une couleur à partir de composantes entre 0 et 1.
    public init(rouge: Double, vert: Double, bleu: Double) {
        func octet(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        hex = String(format: "#%02X%02X%02X", octet(rouge), octet(vert), octet(bleu))
    }

    /// Couleurs proposées par défaut : sombres, pour rester lisibles avec un texte clair.
    public static func parDefaut(pour environnement: Environnement) -> CouleurFond {
        switch environnement {
        case .production: CouleurFond(hex: "#2A0B0F")!
        case .test: CouleurFond(hex: "#0B1630")!
        case .ancien: CouleurFond(hex: "#26272B")!
        }
    }
}

/// Séquences d'échappement utilisées au début des scripts ouverts par Terminal.
enum SequencesTerminal {
    /// Efface l'écran et l'historique : masque la ligne « …command ; exit; » tapée par Terminal.
    static let effacer = #"printf '\033[H\033[2J\033[3J'"#

    /// Change le fond de la fenêtre courante uniquement (OSC 11).
    static func fond(_ couleur: CouleurFond) -> String {
        #"printf '\033]11;%s\007' "# + Shell.citer(couleur.hex)
    }
}
