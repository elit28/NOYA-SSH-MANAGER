# Journal des modifications

Toutes les modifications notables de ce projet sont consignées ici.
Le format s'inspire de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) et le projet suit le [versionnage sémantique](https://semver.org/lang/fr/).

## [Non publié]

## [0.1.0] - Préversion en cours

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
