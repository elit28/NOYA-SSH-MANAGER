import Foundation
import XCTest
@testable import NoyaCore

final class ValidationAliasTests: XCTestCase {
    func testAliasValides() {
        for alias in ["crm", "web-production", "app", "srv_01", "web.prod", "A1", "x"] {
            XCTAssertTrue(ValidationAlias.estValide(alias), "« \(alias) » devrait être valide")
        }
    }

    func testAliasVide() {
        XCTAssertThrowsError(try ValidationAlias.valider("")) { erreur in
            XCTAssertEqual(erreur as? ErreurAlias, .vide)
        }
    }

    func testTiretInitialInterdit() {
        for alias in ["-oProxyCommand=touch /tmp/x", "-v", "--"] {
            XCTAssertThrowsError(try ValidationAlias.valider(alias)) { erreur in
                XCTAssertEqual(erreur as? ErreurAlias, .commenceParTiret)
            }
        }
    }

    func testCaracteresDangereuxRefuses() {
        let tentatives = [
            "crm; rm -rf ~", "crm && ls", "$(whoami)", "`id`", "crm|cat", "crm'", "crm\"",
            "crm\n", "user@crm", "crm crm", "crm/..", "créa", "crm\u{0}", "*", "crm?",
        ]
        for alias in tentatives {
            XCTAssertFalse(ValidationAlias.estValide(alias), "« \(alias) » devrait être refusé")
        }
    }

    func testLongueurMaximale() {
        XCTAssertTrue(ValidationAlias.estValide(String(repeating: "a", count: ValidationAlias.longueurMaximale)))
        XCTAssertThrowsError(try ValidationAlias.valider(String(repeating: "a", count: ValidationAlias.longueurMaximale + 1)))
    }

    func testMessagesEnFrancais() {
        XCTAssertEqual(ErreurAlias.vide.errorDescription, "L'alias SSH est obligatoire.")
        XCTAssertEqual(
            ErreurAlias.caractereInterdit(" ").errorDescription,
            "Caractère espace non autorisé : utilisez uniquement des lettres, des chiffres, « . », « _ » et « - »."
        )
    }
}

final class CommandeSSHTests: XCTestCase {
    func testArgumentsEtTextes() throws {
        let commande = try CommandeSSH(alias: "crm")
        XCTAssertEqual(commande.arguments, ["--", "crm"])
        XCTAssertEqual(commande.texteAffiche, "/usr/bin/ssh -- crm")
        XCTAssertEqual(commande.texteACopier, "ssh crm")
    }

    func testAliasInvalideRefuse() {
        XCTAssertThrowsError(try CommandeSSH(alias: "-oProxyCommand=id"))
        XCTAssertThrowsError(try CommandeSSH(alias: "crm;id"))
    }

    func testScriptTerminal() throws {
        let script = try CommandeSSH(alias: "web-production").scriptTerminal()
        XCTAssertTrue(script.hasPrefix("#!/bin/sh\n"))
        XCTAssertTrue(script.contains("rm -f -- \"$0\"\n"))
        XCTAssertTrue(script.contains("exec '/usr/bin/ssh' -- 'web-production'\n"))
        XCTAssertFalse(script.contains("StrictHostKeyChecking"))
        XCTAssertTrue(script.hasSuffix("\n"))
    }

    func testScriptSyntaxeShellValide() throws {
        let script = try CommandeSSH(alias: "web.prod_01").scriptTerminal()
        let fichier = FileManager.default.temporaryDirectory.appendingPathComponent("noya-test-\(UUID()).command")
        try script.write(to: fichier, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fichier) }

        let processus = Process()
        processus.executableURL = URL(fileURLWithPath: "/bin/sh")
        processus.arguments = ["-n", fichier.path]
        try processus.run()
        processus.waitUntilExit()
        XCTAssertEqual(processus.terminationStatus, 0, "Le script doit être syntaxiquement valide")
    }

    func testCitationShellLitterale() async throws {
        let piegees = ["simple", "avec espace", "l'apostrophe", "$(id) `id` ; | & > <", "\"guillemets\"", "''", "a'\\'b"]
        for texte in piegees {
            let resultat = try await ExecuteurProcessus.executer(
                "/bin/sh",
                arguments: ["-c", "printf %s \(Shell.citer(texte))"]
            )
            XCTAssertEqual(resultat.sortie, texte, "La citation doit restituer « \(texte) » à l'identique")
        }
    }
}
