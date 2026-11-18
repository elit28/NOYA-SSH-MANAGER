Application macOS native (SwiftUI) de gestion des connexions SSH, entièrement en français.

Le détail des changements figure dans [CHANGELOG.md](https://github.com/elit28/NOYA-SSH-MANAGER/blob/main/CHANGELOG.md).

## ⚠️ Préversion non signée et non notarisée

Cette archive est compilée automatiquement par GitHub Actions avec une **signature ad hoc**. Elle n'est **ni signée avec un certificat Developer ID, ni notarisée par Apple**. Au premier lancement, macOS bloquera donc l'ouverture.

Pour l'autoriser :

1. Décompressez l'archive et placez **NOYA SSH Manager** dans le dossier Applications.
2. Ouvrez l'application une première fois : macOS affiche un avertissement.
3. Ouvrez **Réglages Système › Confidentialité et sécurité**, puis cliquez sur **Ouvrir quand même** en face de NOYA SSH Manager.

Vérifiez l'intégrité de l'archive avec le fichier `.sha256` fourni :

```bash
shasum -a 256 -c NOYA-SSH-Manager-*.zip.sha256
```

Configuration requise : macOS 14 Sonoma ou plus récent, Mac Apple Silicon ou Intel.
