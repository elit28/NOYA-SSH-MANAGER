import Foundation
import XCTest
@testable import NoyaCore

final class StockageTests: XCTestCase {
    var dossier: URL!

    override func setUpWithError() throws {
        dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noya-stockage-\(UUID())")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dossier)
    }

    func testFichierAbsentDonneListeVide() throws {
        let stockage = StockageServeurs(url: dossier.appendingPathComponent("serveurs.json"))
        XCTAssertEqual(try stockage.charger(), [])
    }

    func testAllerRetour() throws {
        let stockage = StockageServeurs(url: dossier.appendingPathComponent("sous/serveurs.json"))
        let serveurs = [
            Serveur(nom: "Serveur web", alias: "web", groupe: "Client A", environnement: .production, notes: "Note"),
            Serveur(nom: "Ancien", alias: "old", groupe: "", environnement: .ancien),
        ]
        try stockage.enregistrer(serveurs)
        XCTAssertEqual(try stockage.charger(), serveurs)

        let attributs = try FileManager.default.attributesOfItem(atPath: stockage.url.path)
        XCTAssertEqual((attributs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testFormatJSONLisible() throws {
        let donnees = try StockageServeurs.encoder([Serveur(nom: "A", alias: "a")])
        let texte = String(decoding: donnees, as: UTF8.self)
        XCTAssertTrue(texte.contains("\"version\" : 1"))
        XCTAssertTrue(texte.contains("\"alias\" : \"a\""))
        XCTAssertFalse(texte.lowercased().contains("password"))
    }

    func testDecodageTolerant() throws {
        let json = #"[{"alias": "crm"}, {"alias": "web", "nom": "Web", "environnement": "test"}]"#
        let serveurs = try StockageServeurs.decoder(Data(json.utf8))
        XCTAssertEqual(serveurs.count, 2)
        XCTAssertEqual(serveurs[0].nom, "crm")
        XCTAssertEqual(serveurs[0].environnement, .production)
        XCTAssertEqual(serveurs[0].groupeAffiche, "Sans groupe")
        XCTAssertEqual(serveurs[1].environnement, .test)
    }

    func testVersionFutureRefusee() {
        let json = #"{"version": 99, "serveurs": []}"#
        XCTAssertThrowsError(try StockageServeurs.decoder(Data(json.utf8)))
    }

    func testJSONInvalide() {
        XCTAssertThrowsError(try StockageServeurs.decoder(Data("pas du json".utf8)))
        XCTAssertThrowsError(try StockageServeurs.decoder(Data(#"{"autre": 1}"#.utf8)))
    }
}

final class FusionTests: XCTestCase {
    func testImport() {
        let existants = [Serveur(nom: "CRM", alias: "crm")]
        let nouveaux = [
            Serveur(nom: "CRM bis", alias: "CRM"),
            Serveur(nom: "Web", alias: " web "),
            Serveur(nom: "Web doublon", alias: "web"),
            Serveur(nom: "Piège", alias: "-oProxyCommand=id"),
        ]
        let resultat = Fusion.importer(nouveaux, dans: existants)
        XCTAssertEqual(resultat.ajoutes.map(\.alias), ["web"])
        XCTAssertEqual(resultat.doublons, ["CRM", "web"])
        XCTAssertEqual(resultat.invalides, ["-oProxyCommand=id"])
        XCTAssertEqual(resultat.resume, "1 serveur ajouté, 2 déjà présents, 1 alias invalide ignoré.")
    }
}

final class RechercheTests: XCTestCase {
    let serveurs = [
        Serveur(nom: "CRM Société", alias: "crm", groupe: "Clients"),
        Serveur(nom: "Négoce nouveau", alias: "negoce-n", groupe: "Clients", environnement: .production),
        Serveur(nom: "Négoce ancien", alias: "negoce-a", groupe: "Clients", environnement: .ancien),
        Serveur(nom: "Interne", alias: "int", groupe: ""),
        Serveur(nom: "Éditeur", alias: "edit", groupe: "Atelier"),
    ]

    func testRechercheSansAccentNiCasse() {
        let resultats = serveurs.filter { Recherche.correspond($0, parametres: nil, requete: "negoce") }
        XCTAssertEqual(resultats.map(\.alias), ["negoce-n", "negoce-a"])
        XCTAssertTrue(Recherche.correspond(serveurs[0], parametres: nil, requete: "SOCIETE"))
    }

    func testRechercheMultiTermes() {
        let resultats = serveurs.filter { Recherche.correspond($0, parametres: nil, requete: "négoce ancien") }
        XCTAssertEqual(resultats.map(\.alias), ["negoce-a"])
    }

    func testRechercheSurParametresEffectifs() {
        let parametres = ParametresEffectifs(nomHote: "192.0.2.44", utilisateur: "deploy")
        XCTAssertTrue(Recherche.correspond(serveurs[3], parametres: parametres, requete: "192.0.2"))
        XCTAssertTrue(Recherche.correspond(serveurs[3], parametres: parametres, requete: "deploy"))
        XCTAssertFalse(Recherche.correspond(serveurs[3], parametres: nil, requete: "deploy"))
    }

    func testRequeteVide() {
        XCTAssertTrue(Recherche.correspond(serveurs[0], parametres: nil, requete: "   "))
    }

    func testRegroupement() {
        let groupes = Recherche.grouper(serveurs)
        XCTAssertEqual(groupes.map(\.nom), ["Atelier", "Clients", "Sans groupe"])
        XCTAssertEqual(groupes[1].serveurs.map(\.alias), ["crm", "negoce-a", "negoce-n"])
    }
}

final class DisponibiliteTests: XCTestCase {
    func testFormatLatence() {
        XCTAssertEqual(FormatLatence.texte(.milliseconds(21)), "21 ms")
        XCTAssertEqual(FormatLatence.texte(.microseconds(21_600)), "22 ms")
        XCTAssertEqual(FormatLatence.texte(.microseconds(300)), "< 1 ms")
        XCTAssertEqual(FormatLatence.texte(.milliseconds(1_240)), "1,2 s")
    }

    func testLibelles() {
        XCTAssertEqual(Disponibilite.accessible(latence: .milliseconds(34)).libelleCourt, "34 ms")
        XCTAssertEqual(Disponibilite.inaccessible(raison: "x").libelleCourt, "Inaccessible")
        XCTAssertEqual(Disponibilite.verification.titre, "Vérification en cours…")
        XCTAssertTrue(Disponibilite.accessible(latence: .zero).estAccessible)
        XCTAssertFalse(Disponibilite.inconnue.estAccessible)
    }

    func testDescriptionsErreurs() {
        XCTAssertEqual(DescriptionErreurReseau.texte(codePOSIX: .ECONNREFUSED), "Connexion refusée par le serveur.")
        XCTAssertEqual(DescriptionErreurReseau.delaiDepasse(secondes: 3), "Aucune réponse dans le délai de 3 s.")
    }

    func testPlanification() {
        let maintenant = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(Planification.delaiAvantProchaine(derniere: nil, maintenant: maintenant, intervalle: 30), 0)
        XCTAssertEqual(Planification.delaiAvantProchaine(derniere: maintenant.addingTimeInterval(-10), maintenant: maintenant, intervalle: 30), 20)
        XCTAssertEqual(Planification.delaiAvantProchaine(derniere: maintenant.addingTimeInterval(-45), maintenant: maintenant, intervalle: 30), 0)
        XCTAssertEqual(Planification.delaiAvantProchaine(derniere: maintenant.addingTimeInterval(60), maintenant: maintenant, intervalle: 30), 30)
    }
}

final class ExecuteurProcessusTests: XCTestCase {
    func testSortieEtCode() async throws {
        let resultat = try await ExecuteurProcessus.executer("/bin/sh", arguments: ["-c", "echo bonjour; echo erreur >&2; exit 3"])
        XCTAssertEqual(resultat.sortie, "bonjour\n")
        XCTAssertEqual(resultat.erreurs, "erreur\n")
        XCTAssertEqual(resultat.codeSortie, 3)
        XCTAssertFalse(resultat.expire)
    }

    func testDelaiDepasse() async throws {
        let debut = Date()
        let resultat = try await ExecuteurProcessus.executer("/bin/sleep", arguments: ["10"], delai: .milliseconds(300))
        XCTAssertTrue(resultat.expire)
        XCTAssertLessThan(Date().timeIntervalSince(debut), 5)
    }

    func testExecutableInexistant() async {
        do {
            _ = try await ExecuteurProcessus.executer("/inexistant/programme", arguments: [])
            XCTFail("Une erreur était attendue")
        } catch {}
    }

    func testGrandeSortieSansBlocage() async throws {
        // Plus que la taille d'un tube (64 Ko) sur les deux flux à la fois.
        let resultat = try await ExecuteurProcessus.executer(
            "/bin/sh",
            arguments: ["-c", "head -c 300000 /dev/zero | tr '\\0' a; head -c 300000 /dev/zero | tr '\\0' b >&2"]
        )
        XCTAssertEqual(resultat.sortie.count, 300_000)
        XCTAssertEqual(resultat.erreurs.count, 300_000)
    }
}
