# Contribuer à NOYA SSH Manager

Merci de votre intérêt ! Ce guide explique comment préparer, tester et proposer une modification.

## Signaler un problème ou proposer une idée

- **Problème** : [ouvrez un ticket « Signaler un problème »](https://github.com/elit28/NOYA-SSH-MANAGER/issues/new/choose) en indiquant votre version de macOS et de l'application, ainsi que les étapes pour reproduire.
- **Idée** : utilisez le modèle « Proposer une amélioration ».
- **Faille de sécurité** : ne l'exposez pas publiquement, suivez la [politique de sécurité](SECURITY.md).

Ne publiez jamais d'adresse IP, de nom d'utilisateur ni d'extrait de `~/.ssh/config` réels dans un ticket : remplacez-les par des valeurs fictives (par exemple `192.0.2.10`, `deploy`, `web-prod`).

## Préparer l'environnement

Prérequis : macOS 14 ou plus récent et **Xcode 16** ou plus récent.

```bash
git clone https://github.com/elit28/NOYA-SSH-MANAGER.git
```

```bash
cd NOYA-SSH-MANAGER && open NoyaSSHManager.xcodeproj
```

Aucune dépendance externe n'est nécessaire.

## Organisation du code

| Dossier | Rôle |
|---|---|
| `NoyaCore/` | Paquet Swift sans interface (Foundation uniquement, mode Swift 6 strict). Toute la logique testable : validation, lecture de la configuration SSH, stockage, recherche. |
| `NoyaSSHManager/` | Application SwiftUI : vues, état (`ServeurStore`), vérification TCP, ouverture de Terminal. |
| `scripts/` | Compilation, notarisation, génération de l'icône. |
| `docs/` | Ressources de documentation. |

## Tester

Les tests du cœur tournent sous macOS comme sous Linux :

```bash
swift test --package-path NoyaCore
```

Compilation complète de l'application (produit `dist/NOYA-SSH-Manager-<version>.zip`) :

```bash
./scripts/compiler.sh
```

L'intégration continue exécute ces deux étapes à chaque modification : une contribution doit les passer.

## Règles du projet

1. **Français partout** : interface, messages d'erreur, documentation, commentaires. Les noms de types et de fonctions sont aussi en français ; seuls les termes imposés par Swift, les API ou les protocoles restent en anglais.
2. **Sécurité avant tout** :
   - ne jamais lire, copier ni stocker de mot de passe ou de clé privée ;
   - ne jamais modifier `~/.ssh/config` ;
   - ne jamais ajouter d'option à `ssh` (en particulier `StrictHostKeyChecking`) ;
   - ne jamais construire de commande shell à partir d'un texte non validé ;
   - ne jamais exécuter de commande distante sans action explicite de l'utilisateur.
3. **Sobriété** : pas de dépendance externe, pas de processus en arrière-plan, pas de boucle active. Les tâches périodiques doivent s'arrêter quand la fenêtre n'est plus au premier plan.
4. **Logique testable dans `NoyaCore`** : tout ce qui ne dépend pas de SwiftUI, AppKit ou Network.framework y a sa place, avec ses tests.
5. **Accessibilité** : la couleur n'est jamais le seul indicateur ; les boutons à icône seule ont un libellé d'accessibilité.

## Proposer une modification

1. Créez une branche à partir de `main`.
2. Faites des commits courts, avec un message en français qui explique le pourquoi.
3. Ajoutez une ligne dans la section « Non publié » de [CHANGELOG.md](CHANGELOG.md).
4. Ouvrez une pull request en remplissant le modèle proposé.

## Publier une version (mainteneurs)

1. Mettez à jour `MARKETING_VERSION` dans le projet Xcode (versionnage sémantique).
2. Renommez la section « Non publié » de `CHANGELOG.md` avec le numéro et la date.
3. Publiez : soit en poussant la balise correspondante (par exemple `v0.2.0`), soit depuis l'onglet **Actions › Publication › Run workflow** en indiquant `0.2.0`. Le workflow vérifie la version, lance les tests, compile l'application, crée la balise et la version sur GitHub Releases.
4. Pour une version signée et notarisée, utilisez `scripts/notariser.sh` (compte Apple Developer requis).
