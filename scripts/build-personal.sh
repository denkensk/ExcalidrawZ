#!/bin/zsh
# Builds the self-signed ExcalidrawZ (with partial text colors) and installs it
# to ~/Applications, next to (not over) an official copy in /Applications.
#
#   1. builds the Excalidraw core fork checked out next to this repo
#   2. copies it into the app's resources (ExcalidrawZ/Resources/excalidraw-latest)
#   3. fetches the Swift packages and builds the app's Release configuration,
#      signed to run locally
#
# Overrides: CORE=<core checkout> DEST=<installed app path> SKIP_CORE=1
set -euo pipefail

REPO="${0:A:h:h}"
CORE="${CORE:-${REPO:h}/excalidraw}"
DERIVED="$REPO/build/DerivedData"
DEST="${DEST:-$HOME/Applications/ExcalidrawZ Personal.app}"

if [[ -z "${SKIP_CORE:-}" ]]; then
  echo "==> Building the Excalidraw core in $CORE"
  (cd "$CORE" && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack yarn build)
  rm -rf "$REPO/ExcalidrawZ/Resources/excalidraw-latest"
  cp -R "$CORE/excalidraw-app/build" "$REPO/ExcalidrawZ/Resources/excalidraw-latest"
fi

echo "==> Fetching the Swift packages"
# source archives instead of git clones: see fetch-packages.py
python3 -I "$REPO/scripts/fetch-packages.py"

echo "==> Building the app"
# The Quick Look extension targets $(RECOMMENDED_MACOSX_DEPLOYMENT_TARGET),
# which Xcode 26 resolves to 11.0 — below what its packages need: pin it to
# the app's 13.0 (package targets set their own deployment targets).
xcodebuild \
  -workspace "$REPO/build/ExcalidrawZPersonal.xcworkspace" \
  -scheme ExcalidrawZ \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  ENABLE_HARDENED_RUNTIME=NO \
  RECOMMENDED_MACOSX_DEPLOYMENT_TARGET=13.0 \
  build

echo "==> Installing to $DEST"
mkdir -p "${DEST:h}"
rm -rf "$DEST"
cp -R "$DERIVED/Build/Products/Release/ExcalidrawZ.app" "$DEST"
echo "Done. Open it with: open \"$DEST\""
