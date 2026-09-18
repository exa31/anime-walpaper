#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$ROOT_DIR/macos"
DIST_DIR="$ROOT_DIR/dist/macos"
APP_NAME="Anime Wallpaper"
BUNDLE_DIR="$DIST_DIR/$APP_NAME.app"
RAW_VERSION="${1:-v1.0.0}"
if [[ "$RAW_VERSION" == v* ]]; then
    TAG="$RAW_VERSION"
    CLEAN_VERSION="${RAW_VERSION#v}"
else
    TAG="v$RAW_VERSION"
    CLEAN_VERSION="$RAW_VERSION"
fi

echo "🌸 Building Anime Wallpaper for macOS ($TAG)..."

# 1. Compile Swift in Release mode
cd "$MACOS_DIR"
swift build -c release

# 2. Setup bundle structure
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# 3. Copy executable
cp "$MACOS_DIR/.build/release/AnimeWallpaper" "$BUNDLE_DIR/Contents/MacOS/AnimeWallpaper"
chmod +x "$BUNDLE_DIR/Contents/MacOS/AnimeWallpaper"

# 4. Generate AppIcon.icns from Resources/app.png if available
if [ -f "$ROOT_DIR/Resources/app.png" ]; then
    echo "🎨 Generating AppIcon.icns..."
    ICONSET_DIR="/tmp/AnimeWallpaper.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    sips -z 16 16     "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1 || true
    sips -z 32 32     "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1 || true
    sips -z 32 32     "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1 || true
    sips -z 64 64     "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1 || true
    sips -z 128 128   "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1 || true
    sips -z 256 256   "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1 || true
    sips -z 256 256   "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1 || true
    sips -z 512 512   "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1 || true
    sips -z 512 512   "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1 || true
    sips -z 1024 1024 "$ROOT_DIR/Resources/app.png" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1 || true

    iconutil -c icns "$ICONSET_DIR" -o "$BUNDLE_DIR/Contents/Resources/AppIcon.icns" || true
    rm -rf "$ICONSET_DIR"
fi

# 5. Create Info.plist (LSUIElement = true ensures it runs in Menu Bar without dock icon)
cat <<EOF > "$BUNDLE_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AnimeWallpaper</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.animewallpaper</string>
    <key>CFBundleName</key>
    <string>Anime Wallpaper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$CLEAN_VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "📦 Packaging ZIP archive..."
cd "$DIST_DIR"
ZIP_NAME="AnimeWallpaper-$TAG-macos-arm64.zip"
rm -f "$ZIP_NAME"
zip -r -q -y "$ZIP_NAME" "$APP_NAME.app"

echo "✨ Build succeeded!"
echo "📍 Application Bundle: $BUNDLE_DIR"
echo "📦 Distributable ZIP:   $DIST_DIR/$ZIP_NAME"
