import Foundation

/// Environnement d'un serveur, affiché sous forme de badge dans l'interface.
public enum Environnement: String, Codable, CaseIterable, Sendable, Identifiable {
    case production
    case test
    case ancien

    public var id: String { rawValue }

    /// Libellé court affiché dans l'interface.
    public var libelle: String {
        switch self {
        case .production: "Production"
        case .test: "Test"
        case .ancien: "Ancien"
        }
    }
}

/// Entrée locale décrivant un serveur.
///
/// Elle ne contient aucun secret : la connexion repose uniquement sur l'alias
/// défini dans `~/.ssh/config`. L'adresse, l'utilisateur et la clé sont lus
/// à la demande avec `ssh -G` et ne sont jamais enregistrés ici.
public struct Serveur: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var nom: String
    public var alias: String
    public var groupe: String
    public var environnement: Environnement
    public var notes: String

    /// Nom affiché pour les serveurs sans groupe.
    public static let groupeParDefaut = "Sans groupe"

    public init(
        id: UUID = UUID(),
        nom: String,
        alias: String,
        groupe: String = "",
        environnement: Environnement = .production,
        notes: String = ""
    ) {
        self.id = id
        self.nom = nom
        self.alias = alias
        self.groupe = groupe
        self.environnement = environnement
        self.notes = notes
    }

    /// Groupe affiché dans la barre latérale.
    public var groupeAffiche: String {
        let propre = groupe.trimmingCharacters(in: .whitespacesAndNewlines)
        return propre.isEmpty ? Self.groupeParDefaut : propre
    }

    /// Nom affiché : le nom saisi, ou l'alias à défaut.
    public var nomAffiche: String {
        let propre = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        return propre.isEmpty ? alias : propre
    }

    private enum CodingKeys: String, CodingKey {
        case id, nom, alias, groupe, environnement, notes
    }

    /// Décodage tolérant : seuls `alias` (et idéalement `nom`) sont requis,
    /// afin de pouvoir importer un fichier JSON écrit à la main.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        alias = try c.decode(String.self, forKey: .alias)
        nom = try c.decodeIfPresent(String.self, forKey: .nom) ?? alias
        groupe = try c.decodeIfPresent(String.self, forKey: .groupe) ?? ""
        environnement = try c.decodeIfPresent(Environnement.self, forKey: .environnement) ?? .production
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}
