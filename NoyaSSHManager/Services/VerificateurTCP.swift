import Foundation
import Network
import NoyaCore

/// Vérification de l'accessibilité d'un port TCP avec Network.framework.
///
/// Une connexion TCP est ouverte puis fermée immédiatement : aucune donnée
/// n'est envoyée, aucune authentification n'est tentée. La latence mesurée
/// correspond au temps d'établissement de la connexion.
enum VerificateurTCP {
    static func verifier(hote: String, port: Int, delai: Int) async -> Disponibilite {
        guard (1...65_535).contains(port), let portReseau = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return .inaccessible(raison: "Port \(port) invalide.")
        }

        let parametres = NWParameters.tcp
        parametres.preferNoProxies = true
        let connexion = NWConnection(host: NWEndpoint.Host(hote), port: portReseau, using: parametres)
        let file = DispatchQueue(label: "noya.verification.tcp")
        let reponse = ReponseUnique()
        let debut = ContinuousClock.now

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Disponibilite, Never>) in
                reponse.definir(continuation)
                connexion.stateUpdateHandler = { etat in
                    switch etat {
                    case .ready:
                        reponse.repondre(.accessible(latence: ContinuousClock.now - debut))
                        connexion.cancel()
                    case .waiting(let erreurReseau), .failed(let erreurReseau):
                        reponse.repondre(.inaccessible(raison: texteErreur(erreurReseau)))
                        connexion.cancel()
                    case .cancelled:
                        reponse.repondre(.inaccessible(raison: "Vérification interrompue."))
                        connexion.stateUpdateHandler = nil
                    default:
                        break
                    }
                }
                connexion.start(queue: file)
                file.asyncAfter(deadline: .now() + .seconds(delai)) {
                    reponse.repondre(.inaccessible(raison: DescriptionErreurReseau.delaiDepasse(secondes: delai)))
                    connexion.cancel()
                }
            }
        } onCancel: {
            connexion.cancel()
        }
    }

    private static func texteErreur(_ erreurReseau: NWError) -> String {
        switch erreurReseau {
        case .posix(let code):
            return DescriptionErreurReseau.texte(codePOSIX: code)
        case .dns:
            return DescriptionErreurReseau.nomIntrouvable
        default:
            return "Erreur réseau : \(erreurReseau.localizedDescription)"
        }
    }
}

/// Garantit que la continuation n'est reprise qu'une seule fois,
/// quel que soit l'événement qui survient en premier.
private final class ReponseUnique: @unchecked Sendable {
    private let verrou = NSLock()
    private var continuation: CheckedContinuation<Disponibilite, Never>?
    private var terminee = false

    func definir(_ continuation: CheckedContinuation<Disponibilite, Never>) {
        verrou.lock()
        self.continuation = continuation
        verrou.unlock()
    }

    func repondre(_ resultat: Disponibilite) {
        verrou.lock()
        guard !terminee, let continuation else {
            verrou.unlock()
            return
        }
        terminee = true
        self.continuation = nil
        verrou.unlock()
        continuation.resume(returning: resultat)
    }
}
