import Foundation

/// Groupe de serveurs affiché dans la barre latérale.
public struct GroupeServeurs: Identifiable, Equatable, Sendable {
    public var nom: String
    public var serveurs: [Serveur]
    public var id: String { nom }

    public init(nom: String, serveurs: [Serveur]) {
        self.nom = nom
        self.serveurs = serveurs
    }
}

/// Recherche et regroupement des serveurs.
public enum Recherche {
    /// Normalise un texte : sans casse ni accents.
    public static func normaliser(_ texte: String) -> String {
        texte.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    /// Vrai si le serveur correspond à la requête (nom, alias, groupe,
    /// environnement, hôte et utilisateur effectifs).
    public static func correspond(_ serveur: Serveur, parametres: ParametresEffectifs?, requete: String) -> Bool {
        let termes = normaliser(requete)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !termes.isEmpty else { return true }

        let champs = [
            serveur.nomAffiche,
            serveur.alias,
            serveur.groupeAffiche,
            serveur.environnement.libelle,
            parametres?.nomHote ?? "",
            parametres?.utilisateur ?? "",
        ]
        let texte = normaliser(champs.joined(separator: " "))
        return termes.allSatisfy { texte.contains($0) }
    }

    /// Regroupe les serveurs par groupe, groupes et serveurs triés par ordre alphabétique.
    public static func grouper(_ serveurs: [Serveur]) -> [GroupeServeurs] {
        let parGroupe = Dictionary(grouping: serveurs, by: \.groupeAffiche)
        return parGroupe.keys
            .sorted(by: precede)
            .map { nom in
                GroupeServeurs(
                    nom: nom,
                    serveurs: (parGroupe[nom] ?? []).sorted { precede($0.nomAffiche, $1.nomAffiche) }
                )
            }
    }

    /// Ordre alphabétique insensible à la casse et aux accents.
    static func precede(_ a: String, _ b: String) -> Bool {
        let na = normaliser(a), nb = normaliser(b)
        return na == nb ? a < b : na < nb
    }
}
