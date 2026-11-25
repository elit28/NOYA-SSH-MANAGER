import Foundation
import XCTest
@testable import NoyaCore

final class CouleurFondTests: XCTestCase {
    func testValidationEtNormalisation() {
        XCTAssertEqual(CouleurFond(hex: "#2a0b0f")?.hex, "#2A0B0F")
        XCTAssertEqual(CouleurFond(hex: " #0B1630 ")?.hex, "#0B1630")
        for invalide in ["2A0B0F", "#2A0B0", "#2A0B0F0", "#GGGGGG", "#2A0B0F;", "#2A'0B0", "", "#", "red", "#2A0B0F\n"] {
            XCTAssertNil(CouleurFond(hex: invalide), "« \(invalide) » devrait être refusée")
        }
    }

    func testComposantesAllerRetour() throws {
        let couleur = try XCTUnwrap(CouleurFond(hex: "#2A0B0F"))
        let c = couleur.composantes
        XCTAssertEqual(CouleurFond(rouge: c.rouge, vert: c.vert, bleu: c.bleu), couleur)
        XCTAssertEqual(CouleurFond(rouge: 2, vert: -1, bleu: 0.5).hex, "#FF0080")
    }

    func testCouleursParDefaut() {
        XCTAssertEqual(CouleurFond.parDefaut(pour: .production).hex, "#2A0B0F")
        XCTAssertEqual(CouleurFond.parDefaut(pour: .test).hex, "#0B1630")
        XCTAssertEqual(CouleurFond.parDefaut(pour: .ancien).hex, "#26272B")
    }

    func testScriptAvecFond() throws {
        let script = try CommandeSSH(alias: "web-prod").scriptTerminal(fond: CouleurFond(hex: "#2A0B0F"))
        XCTAssertTrue(script.contains("printf '\\033]11;%s\\007' '#2A0B0F'\n"))
        XCTAssertTrue(script.contains("printf '\\033[H\\033[2J\\033[3J'\n"))
        XCTAssertTrue(script.hasSuffix("exec '/usr/bin/ssh' -- 'web-prod'\n"))
    }

    func testScriptSansFond() throws {
        let script = try CommandeSSH(alias: "web-prod").scriptTerminal()
        XCTAssertFalse(script.contains("]11;"))
        XCTAssertTrue(script.contains("printf '\\033[H\\033[2J\\033[3J'\n"), "L'effacement s'applique toujours")
    }

    /// Exécute le script (avec /bin/echo à la place de ssh) et vérifie les octets envoyés à Terminal.
    func testOctetsEnvoyesATerminal() async throws {
        let script = try CommandeSSH(alias: "web-prod")
            .scriptTerminal(fond: CouleurFond(hex: "#2A0B0F"))
            .replacingOccurrences(of: "exec '/usr/bin/ssh'", with: "exec '/bin/echo'")
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noya-fond-\(UUID())")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent("connexion.command")
        try script.write(to: fichier, atomically: true, encoding: .utf8)

        let resultat = try await ExecuteurProcessus.executer("/bin/sh", arguments: [fichier.path])
        let attendu = "\u{1B}]11;#2A0B0F\u{07}"
            + "\u{1B}[H\u{1B}[2J\u{1B}[3J"
            + "\u{1B}]0;SSH — web-prod\u{07}"
            + "-- web-prod\n"
        XCTAssertEqual(resultat.sortie, attendu)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fichier.path), "Le script se supprime lui-même")
    }
}
