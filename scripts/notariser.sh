#!/bin/bash
# Signe l'application avec un certificat Developer ID, la fait notariser par
# Apple, agrafe le ticket et produit l'archive de distribution.
#
# Prérequis (non fournis par ce dépôt) :
#   - un compte Apple Developer payant ;
#   - un certificat « Developer ID Application » installé dans le trousseau ;
#   - un profil notarytool enregistré une fois pour toutes :
#       xcrun notarytool store-credentials "noya-notarisation" \
#         --apple-id "vous@exemple.com" --team-id "EQUIPE1234"
#
# Usage :
#   IDENTITE_SIGNATURE="Developer ID Application: Nom Prénom (EQUIPE1234)" \
#   EQUIPE_DEVELOPPEUR="EQUIPE1234" \
#   PROFIL_NOTARISATION="noya-notarisation" \
#   ./scripts/notariser.sh
set -euo pipefail

cd "$(dirname "$0")/.."

: "${IDENTITE_SIGNATURE:?Définissez IDENTITE_SIGNATURE (certificat Developer ID Application).}"
: "${EQUIPE_DEVELOPPEUR:?Définissez EQUIPE_DEVELOPPEUR (Team ID Apple).}"
: "${PROFIL_NOTARISATION:?Définissez PROFIL_NOTARISATION (profil xcrun notarytool).}"

if [ "$IDENTITE_SIGNATURE" = "-" ]; then
  echo "Erreur : la notarisation exige un certificat Developer ID, pas une signature ad hoc." >&2
  exit 1
fi

./scripts/compiler.sh

NOM_APP="NOYA SSH Manager"
APP="build/DerivedData/Build/Products/Release/$NOM_APP.app"
ARCHIVE=$(ls -t dist/NOYA-SSH-Manager-*.zip | head -n 1)

echo "▸ Envoi à Apple pour notarisation (quelques minutes)…"
xcrun notarytool submit "$ARCHIVE" --keychain-profile "$PROFIL_NOTARISATION" --wait

echo "▸ Agrafage du ticket de notarisation…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "▸ Nouvelle archive avec le ticket agrafé…"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
(cd dist && shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")

echo "▸ Évaluation Gatekeeper :"
spctl --assess --type execute --verbose=2 "$APP"

echo "✓ Archive signée et notarisée : $ARCHIVE"
