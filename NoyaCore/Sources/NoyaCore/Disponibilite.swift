import Foundation

/// État de disponibilité du port SSH d'un serveur.
///
/// « Accessible » signifie seulement qu'une connexion TCP a pu être établie :
/// cela ne garantit pas que l'authentification SSH réussira.
public enum Disponibilite: Equatable, Sendable {
    case inconnue
    case verification
    case accessible(latence: Duration)
    case inaccessible(raison: String)
    case nonVerifiable(raison: String)

    /// Texte court affiché dans la barre latérale.
    public var libelleCourt: String {
        switch self {
        case .inconnue: "Non vérifié"
        case .verification: "Vérification…"
        case .accessible(let latence): FormatLatence.texte(latence)
        case .inaccessible: "Inaccessible"
        case .nonVerifiable: "Non vérifiable"
        }
    }

    /// Titre affiché dans la fiche du serveur.
    public var titre: String {
        switch self {
        case .inconnue: "Disponibilité non vérifiée"
        case .verification: "Vérification en cours…"
        case .accessible: "Port SSH accessible"
        case .inaccessible: "Port SSH inaccessible"
        case .nonVerifiable: "Vérification directe impossible"
        }
    }

    public var estAccessible: Bool {
        if case .accessible = self { return true }
        return false
    }
}

/// Mise en forme des latences en français.
public enum FormatLatence {
    public static func texte(_ duree: Duration) -> String {
        let millisecondes = Double(duree.components.seconds) * 1_000
            + Double(duree.components.attoseconds) / 1e15
        if millisecondes < 1 { return "< 1 ms" }
        if millisecondes < 1_000 { return "\(Int(millisecondes.rounded())) ms" }
        let secondes = (millisecondes / 100).rounded() / 10
        let texte = String(format: "%.1f", secondes).replacingOccurrences(of: ".", with: ",")
        return "\(texte) s"
    }
}

/// Descriptions françaises des erreurs réseau courantes.
public enum DescriptionErreurReseau {
    public static func texte(codePOSIX: POSIXErrorCode) -> String {
        switch codePOSIX {
        case .ECONNREFUSED: "Connexion refusée par le serveur."
        case .ETIMEDOUT: "Délai de connexion dépassé."
        case .EHOSTUNREACH, .EHOSTDOWN: "Hôte injoignable."
        case .ENETUNREACH, .ENETDOWN: "Réseau injoignable."
        case .ECONNRESET: "Connexion réinitialisée par le serveur."
        case .EADDRNOTAVAIL: "Adresse indisponible."
        default: "Erreur réseau (code \(codePOSIX.rawValue))."
        }
    }

    public static func delaiDepasse(secondes: Int) -> String {
        "Aucune réponse dans le délai de \(secondes) s."
    }

    public static let nomIntrouvable = "Nom d'hôte introuvable (DNS)."
}

/// Calcul du moment de la prochaine vérification automatique.
public enum Planification {
    /// Délai à attendre avant la prochaine vérification : zéro si la dernière
    /// est plus ancienne que l'intervalle (ou n'a jamais eu lieu).
    public static func delaiAvantProchaine(derniere: Date?, maintenant: Date, intervalle: TimeInterval) -> TimeInterval {
        guard let derniere else { return 0 }
        let ecoule = maintenant.timeIntervalSince(derniere)
        if ecoule < 0 { return intervalle }
        return max(0, intervalle - ecoule)
    }
}
