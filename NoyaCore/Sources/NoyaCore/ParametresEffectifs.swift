import Foundation

/// Paramètres effectifs d'un alias, tels que calculés par `ssh -G`.
public struct ParametresEffectifs: Equatable, Sendable {
    public var nomHote: String
    public var utilisateur: String?
    public var port: Int
    public var fichiersIdentite: [String]
    public var proxyJump: String?
    public var proxyCommand: String?

    public init(
        nomHote: String,
        utilisateur: String? = nil,
        port: Int = 22,
        fichiersIdentite: [String] = [],
        proxyJump: String? = nil,
        proxyCommand: String? = nil
    ) {
        self.nomHote = nomHote
        self.utilisateur = utilisateur
        self.port = port
        self.fichiersIdentite = fichiersIdentite
        self.proxyJump = proxyJump
        self.proxyCommand = proxyCommand
    }

    /// Vrai si la connexion passe par un serveur intermédiaire : une
    /// vérification TCP directe ne serait alors pas représentative.
    public var passeParUnRebond: Bool { proxyJump != nil || proxyCommand != nil }

    /// Clés explicitement configurées (les clés par défaut d'OpenSSH sont masquées).
    public var clesConfigurees: [String] {
        fichiersIdentite.filter { !Self.estCleParDefaut($0) }
    }

    /// Texte décrivant la ou les clés utilisées.
    public var descriptionCles: String {
        let cles = clesConfigurees
        return cles.isEmpty ? "Clés par défaut ou agent SSH" : cles.joined(separator: ", ")
    }

    static let nomsClesParDefaut: Set<String> = [
        "id_rsa", "id_ecdsa", "id_ecdsa_sk", "id_ed25519", "id_ed25519_sk", "id_xmss", "id_dsa",
    ]

    static func estCleParDefaut(_ chemin: String) -> Bool {
        let url = URL(fileURLWithPath: chemin)
        return nomsClesParDefaut.contains(url.lastPathComponent)
            && url.deletingLastPathComponent().lastPathComponent == ".ssh"
    }
}

/// Analyse de la sortie de `ssh -G alias`.
///
/// `ssh -G` affiche la configuration résolue (une directive par ligne, en
/// minuscules) sans établir de connexion.
public enum AnalyseurSSHG {
    public static func analyser(_ sortie: String) -> ParametresEffectifs? {
        var nomHote: String?
        var utilisateur: String?
        var port = 22
        var identites: [String] = []
        var proxyJump: String?
        var proxyCommand: String?

        for ligneBrute in sortie.split(whereSeparator: \.isNewline) {
            let ligne = ligneBrute.trimmingCharacters(in: .whitespaces)
            guard let espace = ligne.firstIndex(where: { $0 == " " || $0 == "\t" }) else { continue }
            let cle = ligne[..<espace].lowercased()
            let valeur = ligne[espace...].trimmingCharacters(in: .whitespaces)
            guard !valeur.isEmpty else { continue }

            switch cle {
            case "hostname": nomHote = valeur
            case "user": utilisateur = valeur
            case "port": port = Int(valeur) ?? 22
            case "identityfile": identites.append(valeur)
            case "proxyjump": proxyJump = valeur.lowercased() == "none" ? nil : valeur
            case "proxycommand": proxyCommand = valeur.lowercased() == "none" ? nil : valeur
            default: break
            }
        }

        guard let nomHote, !nomHote.isEmpty else { return nil }
        return ParametresEffectifs(
            nomHote: nomHote,
            utilisateur: utilisateur,
            port: port,
            fichiersIdentite: identites,
            proxyJump: proxyJump,
            proxyCommand: proxyCommand
        )
    }
}
