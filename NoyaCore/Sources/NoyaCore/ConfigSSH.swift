import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Lecture seule de `~/.ssh/config`, uniquement pour lister les hôtes
/// disponibles et signaler un alias absent. Le fichier n'est jamais modifié.
///
/// Les paramètres effectifs d'un alias sont, eux, toujours calculés par
/// OpenSSH (`ssh -G`) : ce lecteur ne cherche pas à réimplémenter ssh.
public struct ConfigSSH: Equatable, Sendable {
    /// Motifs d'une ligne `Host`.
    public var blocsHost: [[String]]
    /// Arguments des directives `Include`, dans l'ordre.
    public var inclusions: [String]

    public init(blocsHost: [[String]] = [], inclusions: [String] = []) {
        self.blocsHost = blocsHost
        self.inclusions = inclusions
    }

    // MARK: - Analyse

    /// Analyse le texte d'un fichier de configuration (sans suivre les `Include`).
    public static func analyser(_ texte: String) -> ConfigSSH {
        var config = ConfigSSH()
        for ligne in texte.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            guard let (motCle, arguments) = decouper(String(ligne)) else { continue }
            switch motCle {
            case "host":
                config.blocsHost.append(arguments)
            case "include":
                config.inclusions.append(contentsOf: arguments)
            default:
                break
            }
        }
        return config
    }

    /// Découpe une ligne en mot-clé (minuscules) et arguments.
    /// Gère `Mot-clé valeur`, `Mot-clé=valeur`, les guillemets et les commentaires.
    static func decouper(_ ligne: String) -> (String, [String])? {
        let jetons = jetonsDe(ligne)
        guard var premier = jetons.first else { return nil }
        var arguments = Array(jetons.dropFirst())

        // Forme « Mot-clé=valeur » collée.
        if let egal = premier.firstIndex(of: "=") {
            let reste = String(premier[premier.index(after: egal)...])
            premier = String(premier[..<egal])
            if !reste.isEmpty { arguments.insert(reste, at: 0) }
        } else if arguments.first == "=" {
            arguments.removeFirst()
        } else if let suivant = arguments.first, suivant.hasPrefix("=") {
            arguments[0] = String(suivant.dropFirst())
            if arguments[0].isEmpty { arguments.removeFirst() }
        }
        guard !premier.isEmpty else { return nil }
        return (premier.lowercased(), arguments)
    }

    /// Jetons séparés par des espaces, avec prise en charge des guillemets
    /// doubles. Un jeton commençant par `#` termine la ligne (commentaire).
    static func jetonsDe(_ ligne: String) -> [String] {
        var jetons: [String] = []
        var courant = ""
        var dansGuillemets = false
        var jetonCommence = false

        for caractere in ligne {
            if dansGuillemets {
                if caractere == "\"" {
                    dansGuillemets = false
                } else {
                    courant.append(caractere)
                }
                continue
            }
            if caractere == " " || caractere == "\t" || caractere == "\r" {
                if jetonCommence {
                    jetons.append(courant)
                    courant = ""
                    jetonCommence = false
                }
                continue
            }
            if caractere == "#" && !jetonCommence {
                return jetons
            }
            if caractere == "\"" {
                dansGuillemets = true
                jetonCommence = true
                continue
            }
            courant.append(caractere)
            jetonCommence = true
        }
        if jetonCommence { jetons.append(courant) }
        return jetons
    }

    // MARK: - Hôtes

    /// Alias concrets (sans joker ni négation) pouvant servir à la connexion,
    /// dans l'ordre du fichier et sans doublon.
    public var aliasConcrets: [String] {
        var vus = Set<String>()
        var resultat: [String] = []
        for motifs in blocsHost {
            for motif in motifs where !Self.estMotifGenerique(motif) && ValidationAlias.estValide(motif) {
                if vus.insert(motif.lowercased()).inserted {
                    resultat.append(motif)
                }
            }
        }
        return resultat
    }

    /// Vrai si une section `Host` (autre que `Host *`) correspond à l'alias.
    public func definit(_ alias: String) -> Bool {
        blocsHost.contains { motifs in
            var positif = false
            for motif in motifs {
                if motif.hasPrefix("!") {
                    if Self.correspond(alias, motif: String(motif.dropFirst())) { return false }
                } else if motif != "*" && Self.correspond(alias, motif: motif) {
                    positif = true
                }
            }
            return positif
        }
    }

    static func estMotifGenerique(_ motif: String) -> Bool {
        motif.contains("*") || motif.contains("?") || motif.hasPrefix("!")
    }

    /// Correspondance de motif façon OpenSSH (`*`, `?`), insensible à la casse.
    public static func correspond(_ texte: String, motif: String) -> Bool {
        let t = Array(texte.lowercased())
        let m = Array(motif.lowercased())
        var i = 0, j = 0
        var etoile = -1, reprise = 0
        while i < t.count {
            if j < m.count && (m[j] == "?" || m[j] == t[i]) {
                i += 1
                j += 1
            } else if j < m.count && m[j] == "*" {
                etoile = j
                reprise = i
                j += 1
            } else if etoile != -1 {
                j = etoile + 1
                reprise += 1
                i = reprise
            } else {
                return false
            }
        }
        while j < m.count && m[j] == "*" { j += 1 }
        return j == m.count
    }

    // MARK: - Chargement depuis le disque

    /// Charge un fichier et, récursivement, ses `Include` (16 niveaux au plus,
    /// comme OpenSSH). Les chemins relatifs sont résolus depuis `dossierSSH`.
    public static func charger(fichier: URL, dossierSSH: URL, dossierPersonnel: String) -> ConfigSSH {
        var visites = Set<String>()
        var resultat = ConfigSSH()
        chargerRecursif(
            fichier: fichier,
            dossierSSH: dossierSSH,
            dossierPersonnel: dossierPersonnel,
            profondeur: 0,
            visites: &visites,
            resultat: &resultat
        )
        return resultat
    }

    private static func chargerRecursif(
        fichier: URL,
        dossierSSH: URL,
        dossierPersonnel: String,
        profondeur: Int,
        visites: inout Set<String>,
        resultat: inout ConfigSSH
    ) {
        guard profondeur <= 16 else { return }
        let chemin = fichier.standardizedFileURL.path
        guard visites.insert(chemin).inserted,
              let texte = try? String(contentsOf: fichier, encoding: .utf8) else { return }

        let config = analyser(texte)
        resultat.blocsHost.append(contentsOf: config.blocsHost)
        resultat.inclusions.append(contentsOf: config.inclusions)

        for inclusion in config.inclusions {
            let motif = resoudreChemin(inclusion, dossierSSH: dossierSSH, dossierPersonnel: dossierPersonnel)
            for cheminInclus in developper(motif) {
                chargerRecursif(
                    fichier: URL(fileURLWithPath: cheminInclus),
                    dossierSSH: dossierSSH,
                    dossierPersonnel: dossierPersonnel,
                    profondeur: profondeur + 1,
                    visites: &visites,
                    resultat: &resultat
                )
            }
        }
    }

    /// Résout `~` et les chemins relatifs d'une directive `Include`.
    static func resoudreChemin(_ chemin: String, dossierSSH: URL, dossierPersonnel: String) -> String {
        if chemin == "~" { return dossierPersonnel }
        if chemin.hasPrefix("~/") { return dossierPersonnel + String(chemin.dropFirst()) }
        if chemin.hasPrefix("/") { return chemin }
        return dossierSSH.appendingPathComponent(chemin).path
    }

    /// Développe les jokers d'un chemin (glob POSIX), triés par ordre alphabétique.
    static func developper(_ motif: String) -> [String] {
        var resultat = glob_t()
        defer { globfree(&resultat) }
        guard glob(motif, 0, nil, &resultat) == 0 else { return [] }
        var chemins: [String] = []
        for index in 0..<Int(resultat.gl_pathc) {
            if let pointeur = resultat.gl_pathv[index] {
                chemins.append(String(cString: pointeur))
            }
        }
        return chemins
    }
}
