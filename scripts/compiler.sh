#!/bin/bash
# Compile NOYA SSH Manager en mode Release et produit une archive ZIP dans dist/.
#
# Usage :
#   ./scripts/compiler.sh
#
# Variables facultatives :
#   IDENTITE_SIGNATURE  Identité de signature. Par défaut « - » : signature ad hoc,
#                       suffisante pour un usage local mais pas pour Gatekeeper.
#   EQUIPE_DEVELOPPEUR  Identifiant d'équipe Apple (avec un certificat Developer ID).
set -euo pipefail

cd "$(dirname "$0")/.."

PROJET="NoyaSSHManager.xcodeproj"
SCHEMA="NoyaSSHManager"
NOM_APP="NOYA SSH Manager"
DERIVEES="build/DerivedData"
IDENTITE="${IDENTITE_SIGNATURE:--}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Erreur : xcodebuild est introuvable. Installez Xcode 16 ou plus récent." >&2
  exit 1
fi

VERSION=$(xcodebuild -project "$PROJET" -scheme "$SCHEMA" -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^ *MARKETING_VERSION = / { print $2; exit }')
if [ -z "$VERSION" ]; then
  echo "Erreur : impossible de lire MARKETING_VERSION." >&2
  exit 1
fi

OPTIONS_SIGNATURE=(CODE_SIGN_IDENTITY="$IDENTITE" CODE_SIGN_STYLE=Manual)
if [ "$IDENTITE" != "-" ]; then
  OPTIONS_SIGNATURE+=(DEVELOPMENT_TEAM="${EQUIPE_DEVELOPPEUR:-}" OTHER_CODE_SIGN_FLAGS="--timestamp")
fi

echo "▸ Compilation de $NOM_APP $VERSION (Release, signature : $IDENTITE)…"
xcodebuild \
  -project "$PROJET" \
  -scheme "$SCHEMA" \
  -configuration Release \
  -derivedDataPath "$DERIVEES" \
  -destination "generic/platform=macOS" \
  -quiet \
  "${OPTIONS_SIGNATURE[@]}" \
  clean build

APP="$DERIVEES/Build/Products/Release/$NOM_APP.app"
if [ ! -d "$APP" ]; then
  echo "Erreur : application introuvable après compilation ($APP)." >&2
  exit 1
fi

echo "▸ Vérification de la signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "▸ Architectures :"
lipo -info "$APP/Contents/MacOS/$NOM_APP"

mkdir -p dist
ARCHIVE="dist/NOYA-SSH-Manager-$VERSION.zip"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
(cd dist && shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")

echo "✓ Application : $APP"
echo "✓ Archive     : $ARCHIVE"
cat "$ARCHIVE.sha256"
