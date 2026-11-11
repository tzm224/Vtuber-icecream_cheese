#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo "Build requires macOS with Xcode Command Line Tools." >&2; exit 1; }
VERSION="${VERSION:-1.0.0}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must use major.minor.patch." >&2; exit 1; }
APP="dist/CheesePet.app"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/cheese-build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

for arch in arm64 x86_64; do
    swift build -c release --arch "$arch" --scratch-path ".build/$arch"
    bin="$(swift build -c release --arch "$arch" --scratch-path ".build/$arch" --show-bin-path)"
    cp "$bin/CheesePet" "$STAGING/CheesePet-$arch"
done
mkdir -p "$STAGING/CheesePet.app/Contents/MacOS" "$STAGING/CheesePet.app/Contents/Resources"
lipo -create "$STAGING/CheesePet-arm64" "$STAGING/CheesePet-x86_64" \
    -output "$STAGING/CheesePet.app/Contents/MacOS/CheesePet"
cp -R Assets "$STAGING/CheesePet.app/Contents/Resources/Assets"
sed "s/@VERSION@/$VERSION/g" packaging/Info.plist > "$STAGING/CheesePet.app/Contents/Info.plist"
if [[ -f Assets/icon.png ]]; then
    mkdir "$STAGING/AppIcon.iconset"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" Assets/icon.png --out "$STAGING/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
        twice=$((size * 2))
        sips -z "$twice" "$twice" Assets/icon.png --out "$STAGING/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$STAGING/AppIcon.iconset" -o "$STAGING/CheesePet.app/Contents/Resources/AppIcon.icns"
fi
codesign --force --deep --sign - "$STAGING/CheesePet.app"
codesign --verify --deep --strict "$STAGING/CheesePet.app"
mkdir -p dist
# Only generated build outputs are replaced here, never installed user applications.
rm -rf "$APP"
mv "$STAGING/CheesePet.app" "$APP"
ditto -c -k --keepParent --norsrc "$APP" dist/CheesePet-macOS-universal.zip
(cd dist && shasum -a 256 CheesePet-macOS-universal.zip > SHA256SUMS)
lipo -info "$APP/Contents/MacOS/CheesePet"
printf '\nBuilt %s\n' "$APP"
