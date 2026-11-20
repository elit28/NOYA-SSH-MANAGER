# Journal des modifications

Toutes les modifications notables de ce projet sont consignées ici.
Le format s'inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le projet suit le [versionnage sémantique](https://semver.org/lang/fr/).

## [Non publié]

## [0.2.0] - 2026-11-20

### Ajouté

- Raccourci vers l'assistant IA local d'Apple (`fm`, inclus dans macOS 27) : bouton ✨ de la barre d'outils, menu Assistant et raccourci ⌥⌘A. Ouvre `fm chat` dans une nouvelle fenêtre Terminal, avec des consignes d'aide à l'administration système en français.
- Modèle exécuté sur le Mac uniquement (`--model system` lorsque `fm chat` le prend en charge), jamais Private Cloud Compute.
- Diagnostic avant ouverture (licence d'Apple, disponibilité du modèle) avec message en français ; la commande `sudo fm license` est proposée à la copie, jamais exécutée par l'application.
- État de l'assistant dans Réglages › Général. Bouton masqué et menu désactivé avant macOS 27.

### Modifié

- L'ouverture de Terminal accepte n'importe quel script préparé (SSH ou assistant).

## [0.1.0] - 2026-11-18

### Ajouté

- Application macOS native en SwiftUI (macOS 14 minimum), entièrement en français.
- Liste de serveurs par groupe, recherche sans accents ni casse, environnements Production / Test / Ancien.
- Import des hôtes depuis `~/.ssh/config` (lecture seule, prise en charge des `Include`).
- Ajout, modification et suppression d'entrées locales ; import et export JSON.
- Connexion dans une nouvelle fenêtre Terminal avec `/usr/bin/ssh -- alias`, sans AppleScript.
- Paramètres effectifs (hôte, utilisateur, port, clé, rebond) lus avec `ssh -G`.
- Surveillance TCP du port SSH : parallèle, délai de 3 s, latence, actualisation toutes les 30 s uniquement quand la fenêtre est active.
- Réglages : actualisation automatique, intervalle, délai d'expiration, animations.
- Raccourcis clavier macOS, icône, scripts de compilation et de notarisation, intégration continue.

[Non publié]: https://github.com/elit28/NOYA-SSH-MANAGER/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/elit28/NOYA-SSH-MANAGER/releases/tag/v0.2.0
[0.1.0]: https://github.com/elit28/NOYA-SSH-MANAGER/releases/tag/v0.1.0
