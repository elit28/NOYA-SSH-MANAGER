import Foundation

/// Erreurs de validation d'un alias SSH.
public enum ErreurAlias: Error, Equatable, Sendable, LocalizedError {
    case vide
    case tropLong(maximum: Int)
    case commenceParTiret
    case caractereInterdit(Character)

    public var errorDescription: String? {
        switch self {
        case .vide:
            return "L'alias SSH est obligatoire."
        case .tropLong(let maximum):
            return "L'alias SSH ne doit pas dépasser \(maximum) caractères."
        case .commenceParTiret:
            return "L'alias SSH ne peut pas commencer par « - »."
        case .caractereInterdit(let caractere):
            let nom = caractere.isWhitespace ? "espace" : "« \(caractere) »"
            return "Caractère \(nom) non autorisé : utilisez uniquement des lettres, des chiffres, « . », « _ » et « - »."
        }
    }
}

/// Validation stricte des alias SSH.
///
/// L'alias est transmis à `/usr/bin/ssh` comme argument : la liste blanche
/// (lettres et chiffres ASCII, `.`, `_`, `-`) et l'interdiction du tiret
/// initial empêchent toute injection de commande ou d'option
/// (par exemple `-oProxyCommand=…`).
public enum ValidationAlias {
    public static let longueurMaximale = 128

    /// Renvoie l'alias s'il est valide, sinon lève une `ErreurAlias`.
    @discardableResult
    public static func valider(_ alias: String) throws -> String {
        guard !alias.isEmpty else { throw ErreurAlias.vide }
        guard alias.count <= longueurMaximale else {
            throw ErreurAlias.tropLong(maximum: longueurMaximale)
        }
        guard alias.first != "-" else { throw ErreurAlias.commenceParTiret }
        for caractere in alias where !estAutorise(caractere) {
            throw ErreurAlias.caractereInterdit(caractere)
        }
        return alias
    }

    /// Indique si l'alias est valide.
    public static func estValide(_ alias: String) -> Bool {
        (try? valider(alias)) != nil
    }

    private static func estAutorise(_ caractere: Character) -> Bool {
        guard caractere.unicodeScalars.count == 1, let scalaire = caractere.unicodeScalars.first else {
            return false
        }
        switch scalaire.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: // 0-9, A-Z, a-z
            return true
        case 0x2E, 0x5F, 0x2D: // . _ -
            return true
        default:
            return false
        }
    }
}
