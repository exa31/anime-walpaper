#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LINUX_PROJ_DIR="$ROOT_DIR/linux"
DIST_DIR="$ROOT_DIR/dist/linux"

echo "🌸 Building Anime Wallpaper for Linux (v$VERSION)..."

mkdir -p "$DIST_DIR"

dotnet publish "$LINUX_PROJ_DIR/AnimeWallpaper.Linux.csproj" \
    -c Release \
    -r linux-x64 \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:EnableCompressionInSingleFile=true \
    -o "$DIST_DIR"

chmod +x "$DIST_DIR/anime-wallpaper"

echo "✨ Build completed successfully!"
echo "Binary located at: $DIST_DIR/anime-wallpaper"
echo ""
echo "To test run:"
echo "  $DIST_DIR/anime-wallpaper --help"
