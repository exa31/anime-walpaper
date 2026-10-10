#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🛡️  Running Anime Wallpaper Integration & Security Test Suite..."
echo "=============================================================="

# 1. Run Swift tests if swift is available
if command -v swift >/dev/null 2>&1; then
    echo "🍏 [1/2] Running macOS/Swift XCTest suite..."
    (cd "$ROOT_DIR/macos" && swift test --parallel)
    echo "✅ macOS/Swift tests PASSED!"
else
    echo "⚠️  Swift not found, skipping Swift test suite."
fi

echo ""

# 2. Run .NET tests if dotnet is available
if command -v dotnet >/dev/null 2>&1; then
    echo "🐧 [2/2] Running .NET xUnit Integration & Security test suite..."
    (cd "$ROOT_DIR" && dotnet test tests/AnimeWallpaper.Tests/AnimeWallpaper.Tests.csproj --verbosity normal)
    echo "✅ .NET tests PASSED!"
else
    echo "ℹ️  'dotnet' CLI not detected locally in PATH."
    echo "   (Note: .NET xUnit tests are fully configured and automated via GitHub Actions in .github/workflows/ci.yml)"
fi

echo ""
echo "=============================================================="
echo "✨ Integration & Security validation completed!"
