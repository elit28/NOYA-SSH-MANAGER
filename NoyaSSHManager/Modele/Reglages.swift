import Foundation
import NoyaCore

/// Clés des préférences (UserDefaults / @AppStorage).
enum CleReglage {
    static let actualisationAuto = "actualisationAutomatique"
    static let intervalle = "intervalleSecondes"
    static let delai = "delaiSecondes"
    static let animations = "animations"
    static let fondSelonEnvironnement = "fondTerminalSelonEnvironnement"

    /// Clé de la couleur de fond Terminal d'un environnement.
    static func fond(_ environnement: Environnement) -> String {
        "fondTerminal.\(environnement.rawValue)"
    }
}

/// Accès aux préférences en dehors des vues.
enum Reglages {
    static let intervallesProposes = [15, 30, 60, 120, 300]
    static let delaisProposes = [2, 3, 5, 10]

    static let intervalleParDefaut = 30
    static let delaiParDefaut = 3

    static func enregistrerValeursParDefaut() {
        var valeurs: [String: Any] = [
            CleReglage.actualisationAuto: true,
            CleReglage.intervalle: intervalleParDefaut,
            CleReglage.delai: delaiParDefaut,
            CleReglage.animations: true,
            CleReglage.fondSelonEnvironnement: true,
        ]
        for environnement in Environnement.allCases {
            valeurs[CleReglage.fond(environnement)] = CouleurFond.parDefaut(pour: environnement).hex
        }
        UserDefaults.standard.register(defaults: valeurs)
    }

    /// Couleur de fond de la fenêtre Terminal pour un environnement, ou nil si l'option est désactivée.
    /// Une valeur enregistrée invalide est remplacée par la couleur par défaut.
    static func fondTerminal(pour environnement: Environnement) -> CouleurFond? {
        guard UserDefaults.standard.bool(forKey: CleReglage.fondSelonEnvironnement) else { return nil }
        let enregistree = UserDefaults.standard.string(forKey: CleReglage.fond(environnement)) ?? ""
        return CouleurFond(hex: enregistree) ?? CouleurFond.parDefaut(pour: environnement)
    }

    static var actualisationAuto: Bool {
        UserDefaults.standard.bool(forKey: CleReglage.actualisationAuto)
    }

    static var intervalleSecondes: TimeInterval {
        let valeur = UserDefaults.standard.integer(forKey: CleReglage.intervalle)
        return TimeInterval(valeur >= 5 ? valeur : intervalleParDefaut)
    }

    static var delaiSecondes: Int {
        let valeur = UserDefaults.standard.integer(forKey: CleReglage.delai)
        return (1...30).contains(valeur) ? valeur : delaiParDefaut
    }

    /// « 30 secondes », « 1 minute », « 5 minutes ».
    static func libelleIntervalle(_ secondes: Int) -> String {
        if secondes < 60 { return "\(secondes) secondes" }
        let minutes = secondes / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    /// « toutes les 30 s », « toutes les minutes », « toutes les 2 min ».
    static func libelleIntervalleCourt(_ secondes: Int) -> String {
        if secondes < 60 { return "toutes les \(secondes) s" }
        let minutes = secondes / 60
        return minutes == 1 ? "toutes les minutes" : "toutes les \(minutes) min"
    }
}

/// Heures affichées au format français, quelle que soit la région du Mac.
enum FormatHeure {
    static func texte(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .standard).locale(Locale(identifier: "fr_FR")))
    }
}
