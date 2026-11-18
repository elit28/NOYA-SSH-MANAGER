import Foundation

/// Commande de connexion SSH construite à partir d'un alias validé.
///
/// Aucune option n'est ajoutée : l'authentification, la vérification des
/// empreintes (`StrictHostKeyChecking`) et tous les autres paramètres restent
/// ceux définis par l'utilisateur dans sa configuration OpenSSH.
public struct CommandeSSH: Sendable, Equatable {
    /// Client OpenSSH fourni par macOS.
    public static let executable = "/usr/bin/ssh"

    public let alias: String

    public init(alias: String) throws {
        self.alias = try ValidationAlias.valider(alias)
    }

    /// Arguments passés à `ssh`. Le `--` interdit d'interpréter l'alias comme une option.
    public var arguments: [String] { ["--", alias] }

    /// Commande exacte, affichée dans l'interface par transparence.
    public var texteAffiche: String { "\(Self.executable) -- \(alias)" }

    /// Commande copiée dans le presse-papiers.
    public var texteACopier: String { "ssh \(alias)" }

    /// Contenu du script temporaire ouvert par Terminal.app.
    ///
    /// Le script se supprime dès son lancement, définit le titre de la
    /// fenêtre puis remplace son processus par `ssh` (`exec`).
    public func scriptTerminal() -> String {
        let aliasCite = Shell.citer(alias)
        let titreCite = Shell.citer("SSH — \(alias)")
        return """
        #!/bin/sh
        # Fichier temporaire créé par NOYA SSH Manager. Il se supprime lui-même.
        rm -f -- "$0"
        printf '\\033]0;%s\\007' \(titreCite)
        exec \(Shell.citer(Self.executable)) -- \(aliasCite)

        """
    }
}

/// Outils de citation pour le shell POSIX.
public enum Shell {
    /// Entoure la chaîne d'apostrophes en échappant les apostrophes internes.
    /// Le résultat est toujours interprété littéralement par `sh`.
    public static func citer(_ texte: String) -> String {
        "'" + texte.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
