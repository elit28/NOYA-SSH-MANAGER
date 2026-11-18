import AppKit
import NoyaCore

/// Erreurs d'ouverture d'une session dans Terminal.app.
enum ErreurLancement: LocalizedError {
    case terminalIntrouvable
    case ecriture(String)
    case ouverture(String)

    var errorDescription: String? {
        switch self {
        case .terminalIntrouvable:
            "Terminal.app est introuvable sur ce Mac."
        case .ecriture(let detail):
            "Impossible de préparer la session : \(detail)"
        case .ouverture(let detail):
            "Impossible d'ouvrir Terminal.app : \(detail)"
        }
    }
}

/// Ouverture d'une session SSH dans une nouvelle fenêtre Terminal.app.
///
/// Méthode : un court script `.command` (droits 0700, dans le dossier
/// temporaire privé de l'utilisateur) est ouvert avec Terminal. Le script se
/// supprime lui-même puis exécute `/usr/bin/ssh -- alias`.
///
/// Cette méthode n'utilise pas AppleScript : elle ne demande donc pas
/// l'autorisation « Automatisation » de macOS et ne construit aucune commande
/// à partir d'un texte libre (l'alias est validé par liste blanche).
enum LanceurTerminal {
    static let identifiantTerminal = "com.apple.Terminal"
    private static let prefixe = "noya-ssh-"
    private static let extensionScript = "command"

    @MainActor
    static func ouvrir(_ commande: CommandeSSH) async throws {
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifiantTerminal) else {
            throw ErreurLancement.terminalIntrouvable
        }
        let script = try ecrireScript(commande)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.open([script], withApplicationAt: terminal, configuration: configuration)
        } catch {
            try? FileManager.default.removeItem(at: script)
            throw ErreurLancement.ouverture(error.localizedDescription)
        }
    }

    static func ecrireScript(_ commande: CommandeSSH) throws -> URL {
        let nom = "\(prefixe)\(UUID().uuidString).\(extensionScript)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nom, isDirectory: false)
        let donnees = Data(commande.scriptTerminal().utf8)
        let cree = FileManager.default.createFile(
            atPath: url.path,
            contents: donnees,
            attributes: [.posixPermissions: 0o700]
        )
        guard cree else {
            throw ErreurLancement.ecriture("le fichier temporaire n'a pas pu être créé.")
        }
        return url
    }

    /// Supprime les scripts restés en place (par exemple si Terminal n'a pas pu les ouvrir).
    static func nettoyerAnciensScripts(ageMinimal: TimeInterval = 60) {
        let gestionnaire = FileManager.default
        let dossier = gestionnaire.temporaryDirectory
        guard let fichiers = try? gestionnaire.contentsOfDirectory(
            at: dossier,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let limite = Date().addingTimeInterval(-ageMinimal)
        for fichier in fichiers where fichier.lastPathComponent.hasPrefix(prefixe) && fichier.pathExtension == extensionScript {
            let date = (try? fichier.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if (date ?? .distantPast) < limite {
                try? gestionnaire.removeItem(at: fichier)
            }
        }
    }
}
