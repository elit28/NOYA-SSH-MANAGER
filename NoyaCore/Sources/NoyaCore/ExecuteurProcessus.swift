import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Résultat de l'exécution d'un processus.
public struct ResultatProcessus: Sendable, Equatable {
    public var codeSortie: Int32
    public var sortie: String
    public var erreurs: String
    public var expire: Bool
}

/// Exécution ponctuelle d'un programme, sans shell, avec délai maximal.
///
/// Les arguments sont transmis tels quels au programme : aucune
/// interprétation par un shell, donc aucune injection possible.
public enum ExecuteurProcessus {
    public static func executer(
        _ executable: String,
        arguments: [String],
        delai: Duration = .seconds(5)
    ) async throws -> ResultatProcessus {
        let secondes = Double(delai.components.seconds) + Double(delai.components.attoseconds) / 1e18
        // Files dédiées : les lectures bloquantes ne doivent pas occuper les
        // fils de la file globale, sinon le minuteur pourrait ne jamais s'exécuter.
        let fileTravail = DispatchQueue(label: "noya.processus.travail", qos: .userInitiated)
        let fileLecture = DispatchQueue(label: "noya.processus.lecture", qos: .userInitiated)
        let fileMinuteur = DispatchQueue(label: "noya.processus.minuteur", qos: .userInitiated)
        return try await withCheckedThrowingContinuation { continuation in
            fileTravail.async {
                let processus = Process()
                processus.executableURL = URL(fileURLWithPath: executable)
                processus.arguments = arguments
                processus.standardInput = FileHandle.nullDevice
                let tubeSortie = Pipe()
                let tubeErreurs = Pipe()
                processus.standardOutput = tubeSortie
                processus.standardError = tubeErreurs

                do {
                    try processus.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let boite = BoiteProcessus(processus)
                let minuteur = DispatchWorkItem {
                    boite.interrompre(fileMinuteur)
                }
                fileMinuteur.asyncAfter(deadline: .now() + secondes, execute: minuteur)

                // Les deux tubes sont lus en parallèle pour éviter tout blocage.
                let lectureErreurs = BoiteDonnees()
                let groupe = DispatchGroup()
                groupe.enter()
                let lecteurErreurs = tubeErreurs.fileHandleForReading
                fileLecture.async {
                    lectureErreurs.definir(lecteurErreurs.readDataToEndOfFile())
                    groupe.leave()
                }
                let donneesSortie = tubeSortie.fileHandleForReading.readDataToEndOfFile()
                groupe.wait()
                processus.waitUntilExit()
                minuteur.cancel()

                continuation.resume(returning: ResultatProcessus(
                    codeSortie: processus.terminationStatus,
                    sortie: String(decoding: donneesSortie, as: UTF8.self),
                    erreurs: String(decoding: lectureErreurs.valeur, as: UTF8.self),
                    expire: boite.aExpire
                ))
            }
        }
    }
}

/// Accès protégé au processus depuis le minuteur.
private final class BoiteProcessus: @unchecked Sendable {
    private let verrou = NSLock()
    private let processus: Process
    private var expire = false

    init(_ processus: Process) {
        self.processus = processus
    }

    /// Demande l'arrêt (SIGTERM), puis force l'arrêt (SIGKILL) 0,5 s plus tard.
    /// SIGKILL est nécessaire si le processus a hérité d'un masque bloquant
    /// SIGTERM (cas des fils de libdispatch sous Linux).
    func interrompre(_ file: DispatchQueue) {
        verrou.lock()
        defer { verrou.unlock() }
        guard processus.isRunning else { return }
        expire = true
        processus.terminate()
        file.asyncAfter(deadline: .now() + 0.5) { [self] in
            forcerArret()
        }
    }

    private func forcerArret() {
        verrou.lock()
        defer { verrou.unlock() }
        if processus.isRunning {
            kill(processus.processIdentifier, SIGKILL)
        }
    }

    var aExpire: Bool {
        verrou.lock()
        defer { verrou.unlock() }
        return expire
    }
}

/// Données partagées entre deux files, protégées par un verrou.
private final class BoiteDonnees: @unchecked Sendable {
    private let verrou = NSLock()
    private var donnees = Data()

    func definir(_ nouvelles: Data) {
        verrou.lock()
        donnees = nouvelles
        verrou.unlock()
    }

    var valeur: Data {
        verrou.lock()
        defer { verrou.unlock() }
        return donnees
    }
}
