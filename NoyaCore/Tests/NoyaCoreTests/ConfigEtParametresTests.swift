import Foundation
import XCTest
@testable import NoyaCore

final class AnalyseurSSHGTests: XCTestCase {
    // Extrait réel de `ssh -G` (OpenSSH 9.6).
    let exemple = """
    user deploy
    hostname 192.0.2.10
    port 2222
    addressfamily any
    identityfile ~/.ssh/id_ed25519_demo
    stricthostkeychecking ask
    """

    func testAnalyseComplete() throws {
        let parametres = try XCTUnwrap(AnalyseurSSHG.analyser(exemple))
        XCTAssertEqual(parametres.nomHote, "192.0.2.10")
        XCTAssertEqual(parametres.utilisateur, "deploy")
        XCTAssertEqual(parametres.port, 2222)
        XCTAssertEqual(parametres.fichiersIdentite, ["~/.ssh/id_ed25519_demo"])
        XCTAssertFalse(parametres.passeParUnRebond)
        XCTAssertEqual(parametres.descriptionCles, "~/.ssh/id_ed25519_demo")
    }

    func testClesParDefautMasquees() throws {
        let sortie = """
        hostname exemple.org
        identityfile ~/.ssh/id_rsa
        identityfile ~/.ssh/id_ecdsa
        identityfile ~/.ssh/id_ed25519
        """
        let parametres = try XCTUnwrap(AnalyseurSSHG.analyser(sortie))
        XCTAssertEqual(parametres.port, 22)
        XCTAssertNil(parametres.utilisateur)
        XCTAssertTrue(parametres.clesConfigurees.isEmpty)
        XCTAssertEqual(parametres.descriptionCles, "Clés par défaut ou agent SSH")
    }

    func testRebond() throws {
        let avecRebond = try XCTUnwrap(AnalyseurSSHG.analyser("hostname 10.0.0.5\nproxyjump bastion\n"))
        XCTAssertTrue(avecRebond.passeParUnRebond)
        XCTAssertEqual(avecRebond.proxyJump, "bastion")

        let sansRebond = try XCTUnwrap(AnalyseurSSHG.analyser("hostname 10.0.0.5\nproxyjump none\nproxycommand none\n"))
        XCTAssertFalse(sansRebond.passeParUnRebond)
    }

    func testSortieSansHote() {
        XCTAssertNil(AnalyseurSSHG.analyser(""))
        XCTAssertNil(AnalyseurSSHG.analyser("user root\nport 22\n"))
    }
}

final class ConfigSSHTests: XCTestCase {
    let exemple = """
    # Configuration d'exemple
    Include ~/.ssh/config.d/*

    Host crm
        HostName 192.0.2.1
        User ubuntu
        IdentityFile ~/.ssh/id_ed25519_web

    Host web-1 web-2 *.interne !bastion
      HostName=%h.exemple.org

    host=prod.app # commentaire
    HOST "avec-guillemets"
    Host bastion
    Host crm
    Host *
        ServerAliveInterval 30
    Match host foo
        User bar
    """

    func testAnalyse() {
        let config = ConfigSSH.analyser(exemple)
        XCTAssertEqual(config.inclusions, ["~/.ssh/config.d/*"])
        XCTAssertEqual(config.blocsHost.count, 7)
        XCTAssertEqual(config.blocsHost[1], ["web-1", "web-2", "*.interne", "!bastion"])
        XCTAssertEqual(config.blocsHost[2], ["prod.app"])
        XCTAssertEqual(config.blocsHost[3], ["avec-guillemets"])
    }

    func testAliasConcrets() {
        let config = ConfigSSH.analyser(exemple)
        XCTAssertEqual(config.aliasConcrets, ["crm", "web-1", "web-2", "prod.app", "avec-guillemets", "bastion"])
    }

    func testDefinit() {
        let config = ConfigSSH.analyser(exemple)
        XCTAssertTrue(config.definit("crm"))
        XCTAssertTrue(config.definit("CRM"))
        XCTAssertTrue(config.definit("api.interne"))
        XCTAssertFalse(config.definit("inconnu"), "Host * seul ne compte pas comme une définition")
        XCTAssertTrue(config.definit("bastion"))
    }

    func testNegation() {
        let config = ConfigSSH.analyser("Host *.interne !secret.interne\n")
        XCTAssertTrue(config.definit("a.interne"))
        XCTAssertFalse(config.definit("secret.interne"))
    }

    func testCorrespondanceMotifs() {
        XCTAssertTrue(ConfigSSH.correspond("web-12", motif: "web-*"))
        XCTAssertTrue(ConfigSSH.correspond("web-1", motif: "web-?"))
        XCTAssertFalse(ConfigSSH.correspond("web-12", motif: "web-?"))
        XCTAssertTrue(ConfigSSH.correspond("a.b.c", motif: "*.c"))
        XCTAssertTrue(ConfigSSH.correspond("abc", motif: "a*b*c"))
        XCTAssertFalse(ConfigSSH.correspond("abd", motif: "a*c"))
        XCTAssertTrue(ConfigSSH.correspond("", motif: "*"))
        XCTAssertTrue(ConfigSSH.correspond("Serveur", motif: "serveur"))
    }

    func testChargementAvecInclusions() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noya-ssh-\(UUID())")
        let dossierInclus = dossier.appendingPathComponent("config.d")
        try FileManager.default.createDirectory(at: dossierInclus, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }

        try "Include config.d/*.conf\nHost principal\n".write(
            to: dossier.appendingPathComponent("config"), atomically: true, encoding: .utf8)
        try "Host b-inclus\n".write(to: dossierInclus.appendingPathComponent("b.conf"), atomically: true, encoding: .utf8)
        // Inclusion circulaire : doit être ignorée sans boucle infinie.
        try "Host a-inclus\nInclude config\n".write(
            to: dossierInclus.appendingPathComponent("a.conf"), atomically: true, encoding: .utf8)
        try "Host ignore\n".write(to: dossierInclus.appendingPathComponent("autre.txt"), atomically: true, encoding: .utf8)

        let config = ConfigSSH.charger(
            fichier: dossier.appendingPathComponent("config"),
            dossierSSH: dossier,
            dossierPersonnel: "/home/inexistant"
        )
        XCTAssertEqual(config.aliasConcrets, ["principal", "a-inclus", "b-inclus"])
    }

    func testFichierAbsent() {
        let config = ConfigSSH.charger(
            fichier: URL(fileURLWithPath: "/chemin/inexistant/config"),
            dossierSSH: URL(fileURLWithPath: "/chemin/inexistant"),
            dossierPersonnel: "/home/x"
        )
        XCTAssertTrue(config.aliasConcrets.isEmpty)
    }

    func testResolutionChemins() {
        let ssh = URL(fileURLWithPath: "/Users/moi/.ssh")
        XCTAssertEqual(ConfigSSH.resoudreChemin("~/.ssh/a", dossierSSH: ssh, dossierPersonnel: "/Users/moi"), "/Users/moi/.ssh/a")
        XCTAssertEqual(ConfigSSH.resoudreChemin("config.d/*", dossierSSH: ssh, dossierPersonnel: "/Users/moi"), "/Users/moi/.ssh/config.d/*")
        XCTAssertEqual(ConfigSSH.resoudreChemin("/etc/ssh/x", dossierSSH: ssh, dossierPersonnel: "/Users/moi"), "/etc/ssh/x")
    }
}

final class LecteurParametresTests: XCTestCase {
    /// Faux `ssh` : enregistre ses arguments et affiche une sortie de type `ssh -G`.
    func testAvecFauxExecutable() async throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noya-faux-\(UUID())")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let journal = dossier.appendingPathComponent("arguments.txt")
        let faux = dossier.appendingPathComponent("ssh")
        try """
        #!/bin/sh
        printf '%s\\n' "$@" > '\(journal.path)'
        printf 'hostname 192.0.2.7\\nuser admin\\nport 22\\n'
        """.write(to: faux, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: faux.path)

        let parametres = try await LecteurParametres.lire(alias: "srv", executable: faux.path)
        XCTAssertEqual(parametres.nomHote, "192.0.2.7")
        XCTAssertEqual(parametres.utilisateur, "admin")
        XCTAssertEqual(try String(contentsOf: journal, encoding: .utf8), "-G\n--\nsrv\n")
    }

    func testAliasInvalideNeLancePasDeProcessus() async {
        do {
            _ = try await LecteurParametres.lire(alias: "-oProxyCommand=id", executable: "/inexistant")
            XCTFail("Une erreur était attendue")
        } catch let erreur as ErreurParametres {
            guard case .aliasInvalide = erreur else { return XCTFail("Erreur inattendue : \(erreur)") }
        } catch {
            XCTFail("Erreur inattendue : \(error)")
        }
    }

    func testEchecRemonteLeMessage() async {
        do {
            _ = try await LecteurParametres.lire(alias: "x", executable: "/usr/bin/false")
            XCTFail("Une erreur était attendue")
        } catch let erreur as ErreurParametres {
            guard case .echec = erreur else { return XCTFail("Erreur inattendue : \(erreur)") }
        } catch {
            XCTFail("Erreur inattendue : \(error)")
        }
    }

    /// Test d'intégration avec le vrai client OpenSSH, s'il est installé.
    func testAvecVraiOpenSSH() async throws {
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: "/usr/bin/ssh"), "OpenSSH absent")
        let alias = "noya-test-alias-inexistant"
        let parametres = try await LecteurParametres.lire(alias: alias)
        XCTAssertEqual(parametres.nomHote, alias, "Sans section Host, ssh utilise l'alias comme nom d'hôte")
        XCTAssertEqual(parametres.port, 22)
    }
}
