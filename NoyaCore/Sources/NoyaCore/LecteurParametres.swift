import Foundation

/// Erreurs de lecture des paramètres effectifs d'un alias.
public enum ErreurParametres: Error, LocalizedError, Equatable, Sendable {
    case aliasInvalide(String)
    case echec(String)
    case delaiDepasse
    case sortieIllisible

    public var errorDescription: String? {
        switch self {
        case .aliasInvalide(let detail): detail
        case .echec(let message): "ssh -G a échoué : \(message)"
        case .delaiDepasse: "ssh -G n'a pas répondu à temps."
        case .sortieIllisible: "La sortie de ssh -G est illisible."
        }
    }
}

/// Lecture des paramètres effectifs d'un alias avec `ssh -G`.
///
/// `ssh -G` applique `~/.ssh/config` (Include, Match, Host…) exactement comme
/// lors d'une connexion, mais sans se connecter. Aucune clé n'est lue.
public enum LecteurParametres {
    public static func lire(
        alias: String,
        executable: String = CommandeSSH.executable,
        delai: Duration = .seconds(5)
    ) async throws -> ParametresEffectifs {
        do {
            try ValidationAlias.valider(alias)
        } catch {
            throw ErreurParametres.aliasInvalide(error.localizedDescription)
        }

        let resultat: ResultatProcessus
        do {
            resultat = try await ExecuteurProcessus.executer(executable, arguments: ["-G", "--", alias], delai: delai)
        } catch {
            throw ErreurParametres.echec(error.localizedDescription)
        }

        if resultat.expire { throw ErreurParametres.delaiDepasse }
        guard resultat.codeSortie == 0 else {
            let message = resultat.erreurs
                .split(whereSeparator: \.isNewline)
                .first
                .map(String.init) ?? "code de sortie \(resultat.codeSortie)"
            throw ErreurParametres.echec(message)
        }
        guard let parametres = AnalyseurSSHG.analyser(resultat.sortie) else {
            throw ErreurParametres.sortieIllisible
        }
        return parametres
    }
}
