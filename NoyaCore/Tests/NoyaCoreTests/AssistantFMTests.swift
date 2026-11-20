import Foundation
import XCTest
@testable import NoyaCore

final class AssistantFMTests: XCTestCase {
    func testScriptAvecModeleLocalExplicite() throws {
        let script = AssistantFM.scriptTerminal(modeleLocalExplicite: true)
        XCTAssertTrue(script.hasPrefix("#!/bin/sh\n"))
        XCTAssertTrue(script.contains("rm -f -- \"$0\"\n"))
        XCTAssertTrue(script.contains("exec '/usr/bin/fm' chat --model 'system' --instructions '"))
        XCTAssertFalse(script.contains("pcc"), "Le modèle Private Cloud Compute n'est jamais choisi")
        XCTAssertFalse(script.contains("sudo"), "L'application ne lance jamais sudo")
    }

    func testScriptSansOptionModele() {
        let script = AssistantFM.scriptTerminal(modeleLocalExplicite: false)
        XCTAssertTrue(script.contains("exec '/usr/bin/fm' chat --instructions '"))
        XCTAssertFalse(script.contains("--model"))
    }

    func testScriptSyntaxeEtConsignesIntactes() async throws {
        // Les consignes contiennent des apostrophes typographiques et « ~ » : la citation doit les préserver.
        let script = AssistantFM.scriptTerminal(modeleLocalExplicite: true, executable: "/bin/echo")
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noya-fm-\(UUID())")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent("assistant.command")
        try script.write(to: fichier, atomically: true, encoding: .utf8)

        // Exécuté avec /bin/echo à la place de fm : affiche exactement les arguments reçus.
        let resultat = try await ExecuteurProcessus.executer("/bin/sh", arguments: [fichier.path])
        XCTAssertEqual(resultat.codeSortie, 0)
        XCTAssertTrue(resultat.sortie.hasSuffix("chat --model system --instructions \(AssistantFM.consignes)\n"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fichier.path), "Le script se supprime lui-même")
    }

    func testLicence() {
        XCTAssertEqual(AssistantFM.licenceAcceptee(sortie: "Agreed to license FM1 version 1.1", codeSortie: 0), true)
        XCTAssertEqual(AssistantFM.licenceAcceptee(sortie: "Not agreed", codeSortie: 0), false)
        XCTAssertEqual(
            AssistantFM.licenceAcceptee(sortie: "YOU HAVE NOT AGREED TO THE APPLE FOUNDATION MODELS CLI LEGAL NOTICE & TERMS.", codeSortie: 0),
            false
        )
        XCTAssertEqual(AssistantFM.licenceAcceptee(sortie: "", codeSortie: 69), false)
        XCTAssertNil(AssistantFM.licenceAcceptee(sortie: "sortie inattendue", codeSortie: 1))
    }

    func testDisponibilite() {
        XCTAssertEqual(AssistantFM.disponibilite(sortie: "System model available\n"), .pret)
        XCTAssertEqual(
            AssistantFM.disponibilite(sortie: "System model unavailable: modelNotReady"),
            .modeleIndisponible(raison: "Le modèle d’Apple n’est pas encore prêt (téléchargement en cours par macOS). Réessayez plus tard.")
        )
        XCTAssertEqual(
            AssistantFM.disponibilite(sortie: "System model unavailable: autreRaison"),
            .modeleIndisponible(raison: "Le modèle d’Apple n’est pas disponible (autreRaison).")
        )
        XCTAssertEqual(AssistantFM.disponibilite(sortie: "Error: unknown command"), .indetermine)
        XCTAssertEqual(AssistantFM.disponibilite(sortie: ""), .indetermine)
    }

    func testOptionModele() {
        XCTAssertTrue(AssistantFM.chatAccepteModele(aide: "  -m, --model <model>  The model to use"))
        XCTAssertFalse(AssistantFM.chatAccepteModele(aide: "USAGE: fm chat [--instructions <text>]"))
    }

    func testAbsent() async {
        let diagnostic = await AssistantFM.diagnostiquer(executable: "/chemin/inexistant/fm")
        XCTAssertEqual(diagnostic.etat, .absent)
    }

    /// Faux `fm` répondant selon la sous-commande.
    private func fauxFM(licence: String, codeLicence: Int32 = 0, disponibilite: String, aideChat: String) throws -> (URL, URL) {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noya-faux-fm-\(UUID())")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let fichier = dossier.appendingPathComponent("fm")
        try """
        #!/bin/sh
        case "$1" in
          license) printf '%s\\n' \(Shell.citer(licence)); exit \(codeLicence) ;;
          available) printf '%s\\n' \(Shell.citer(disponibilite)) ;;
          chat) printf '%s\\n' \(Shell.citer(aideChat)) ;;
        esac
        """.write(to: fichier, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fichier.path)
        return (dossier, fichier)
    }

    func testDiagnosticPret() async throws {
        let (dossier, fm) = try fauxFM(
            licence: "Agreed to license FM1 version 1.1",
            disponibilite: "System model available",
            aideChat: "OPTIONS: -m, --model <model>"
        )
        defer { try? FileManager.default.removeItem(at: dossier) }
        let diagnostic = await AssistantFM.diagnostiquer(executable: fm.path)
        XCTAssertEqual(diagnostic, AssistantFM.Diagnostic(etat: .pret, modeleLocalExplicite: true))
    }

    func testDiagnosticLicence() async throws {
        let (dossier, fm) = try fauxFM(licence: "Not agreed", codeLicence: 69, disponibilite: "-", aideChat: "-")
        defer { try? FileManager.default.removeItem(at: dossier) }
        let diagnostic = await AssistantFM.diagnostiquer(executable: fm.path)
        XCTAssertEqual(diagnostic.etat, .licenceNonAcceptee)
    }

    func testDiagnosticModeleEnTelechargement() async throws {
        let (dossier, fm) = try fauxFM(
            licence: "Agreed",
            disponibilite: "System model unavailable: modelNotReady",
            aideChat: "USAGE: fm chat [--instructions <text>]"
        )
        defer { try? FileManager.default.removeItem(at: dossier) }
        let diagnostic = await AssistantFM.diagnostiquer(executable: fm.path)
        guard case .modeleIndisponible = diagnostic.etat else { return XCTFail("État inattendu : \(diagnostic.etat)") }
        XCTAssertFalse(diagnostic.modeleLocalExplicite)
    }
}
