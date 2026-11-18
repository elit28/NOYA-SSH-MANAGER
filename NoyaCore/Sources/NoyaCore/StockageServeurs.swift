import Foundation

/// Erreurs de lecture ou d'écriture de la liste des serveurs.
public enum ErreurStockage: Error, LocalizedError, Sendable {
    case lecture(String)
    case ecriture(String)
    case formatInvalide(String)

    public var errorDescription: String? {
        switch self {
        case .lecture(let detail): "Impossible de lire la liste des serveurs : \(detail)"
        case .ecriture(let detail): "Impossible d'enregistrer la liste des serveurs : \(detail)"
        case .formatInvalide(let detail): "Le fichier n'est pas une liste de serveurs valide : \(detail)"
        }
    }
}

/// Format du fichier `serveurs.json`.
public struct DocumentServeurs: Codable, Sendable {
    public static let versionActuelle = 1
    public var version: Int
    public var serveurs: [Serveur]

    public init(version: Int = DocumentServeurs.versionActuelle, serveurs: [Serveur]) {
        self.version = version
        self.serveurs = serveurs
    }
}

/// Lecture et écriture de la liste locale des serveurs (JSON, sans secret).
public struct StockageServeurs: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/NOYA SSH Manager/serveurs.json`.
    public static func emplacementParDefaut() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("NOYA SSH Manager", isDirectory: true)
            .appendingPathComponent("serveurs.json", isDirectory: false)
    }

    /// Charge la liste. Un fichier absent donne une liste vide.
    public func charger() throws -> [Serveur] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let donnees: Data
        do {
            donnees = try Data(contentsOf: url)
        } catch {
            throw ErreurStockage.lecture(error.localizedDescription)
        }
        return try Self.decoder(donnees)
    }

    /// Enregistre la liste de façon atomique, lisible uniquement par l'utilisateur.
    public func enregistrer(_ serveurs: [Serveur]) throws {
        do {
            let dossier = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: dossier,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try Self.encoder(serveurs).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw ErreurStockage.ecriture(error.localizedDescription)
        }
    }

    /// Accepte `{ "version": 1, "serveurs": [...] }` ou directement `[...]`.
    public static func decoder(_ donnees: Data) throws -> [Serveur] {
        let decodeur = JSONDecoder()
        if let document = try? decodeur.decode(DocumentServeurs.self, from: donnees) {
            guard document.version <= DocumentServeurs.versionActuelle else {
                throw ErreurStockage.formatInvalide("version \(document.version) non prise en charge.")
            }
            return document.serveurs
        }
        do {
            return try decodeur.decode([Serveur].self, from: donnees)
        } catch {
            throw ErreurStockage.formatInvalide("structure JSON inattendue.")
        }
    }

    public static func encoder(_ serveurs: [Serveur]) throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encodeur.encode(DocumentServeurs(serveurs: serveurs))
    }
}

/// Résultat d'un import.
public struct ResultatImport: Equatable, Sendable {
    public var ajoutes: [Serveur]
    public var doublons: [String]
    public var invalides: [String]

    public init(ajoutes: [Serveur] = [], doublons: [String] = [], invalides: [String] = []) {
        self.ajoutes = ajoutes
        self.doublons = doublons
        self.invalides = invalides
    }

    /// Résumé lisible du résultat.
    public var resume: String {
        var parties = ["\(ajoutes.count) serveur\(ajoutes.count > 1 ? "s" : "") ajouté\(ajoutes.count > 1 ? "s" : "")"]
        if !doublons.isEmpty {
            parties.append("\(doublons.count) déjà présent\(doublons.count > 1 ? "s" : "")")
        }
        if !invalides.isEmpty {
            parties.append("\(invalides.count) alias invalide\(invalides.count > 1 ? "s" : "") ignoré\(invalides.count > 1 ? "s" : "")")
        }
        return parties.joined(separator: ", ") + "."
    }
}

/// Fusion d'une liste importée dans la liste existante.
public enum Fusion {
    /// Ajoute les serveurs nouveaux. Les alias déjà présents (comparaison
    /// insensible à la casse, comme OpenSSH) et les alias invalides sont ignorés.
    public static func importer(_ nouveaux: [Serveur], dans existants: [Serveur]) -> ResultatImport {
        var connus = Set(existants.map { $0.alias.lowercased() })
        var resultat = ResultatImport()
        for var serveur in nouveaux {
            serveur.alias = serveur.alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard ValidationAlias.estValide(serveur.alias) else {
                resultat.invalides.append(serveur.alias)
                continue
            }
            guard connus.insert(serveur.alias.lowercased()).inserted else {
                resultat.doublons.append(serveur.alias)
                continue
            }
            serveur.id = UUID()
            resultat.ajoutes.append(serveur)
        }
        return resultat
    }
}
