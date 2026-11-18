<#
.SYNOPSIS
    Builds and packages Anime Wallpaper into a self-contained Windows executable, MSI installer, and ZIP release.
.PARAMETER Version
    The release version tag, defaults to "v1.0.0".
.PARAMETER CreateGitHubRelease
    If set to true, uses GitHub CLI (gh) to create a release and upload the zip.
#>
param(
    [string]$Version = "v1.0.0",
    [switch]$CreateGitHubRelease = $false
)

$ErrorActionPreference = "Stop"

# Ensure .NET 8 is in PATH
$dotnetDir = "$env:USERPROFILE\.dotnet"
if (Test-Path $dotnetDir) {
    $env:PATH = "$dotnetDir;$env:PATH"
    $env:DOTNET_ROOT = $dotnetDir
}

# Ensure WiX Toolset v3 is in PATH if installed in Program Files
$wixDir = "C:\Program Files (x86)\WiX Toolset v3.11\bin"
if (Test-Path $wixDir) {
    $env:PATH = "$wixDir;$env:PATH"
}

$cleanVersion = $Version.TrimStart('v')
if ($cleanVersion -notmatch '^\d+\.\d+\.\d+') {
    $cleanVersion = "1.0.0.0"
} elseif ($cleanVersion -match '^\d+\.\d+\.\d+$') {
    $cleanVersion = "$cleanVersion.0"
}

$rootDir = Split-Path -Parent $PSScriptRoot
$distDir = Join-Path $rootDir "dist"
$publishDir = Join-Path $distDir "AnimeWallpaper"
$zipPath = Join-Path $distDir "AnimeWallpaper-$Version-win-x64.zip"
$msiPath = Join-Path $distDir "AnimeWallpaper-$Version-win-x64.msi"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building Anime Wallpaper ($Version)..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}
New-Item -ItemType Directory -Path $publishDir -Force | Out-Null

Write-Host "--> Running dotnet publish..." -ForegroundColor Yellow
dotnet publish "$rootDir\AnimeWallpaper.csproj" `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -o $publishDir

if (-not (Test-Path "$publishDir\AnimeWallpaper.exe")) {
    Write-Error "Build failed: AnimeWallpaper.exe was not created."
}

# Copy documentation
Copy-Item "$rootDir\README.md" -Destination $publishDir -ErrorAction SilentlyContinue
Copy-Item "$rootDir\LICENSE" -Destination $publishDir -ErrorAction SilentlyContinue

Write-Host "--> Compressing to $zipPath..." -ForegroundColor Yellow
Compress-Archive -Path "$publishDir\*" -DestinationPath $zipPath -Force

# Build MSI Installer using WiX if available
$wxsFile = Join-Path $rootDir "installer\AnimeWallpaper.wxs"
if (Get-Command candle -ErrorAction SilentlyContinue) {
    Write-Host "--> Building MSI Installer with WiX Toolset..." -ForegroundColor Yellow
    $wixObj = Join-Path $distDir "AnimeWallpaper.wixobj"
    candle -nologo -dPublishDir="$publishDir" -dSourceDir="$rootDir" -dProductVersion="$cleanVersion" "$wxsFile" -out "$wixObj"
    light -nologo -ext WixUIExtension -sval "$wixObj" -out "$msiPath"
    if (Test-Path $msiPath) {
        Write-Host "--> MSI Installer created: $msiPath" -ForegroundColor Green
    }
} else {
    Write-Host "--> WiX Toolset not found, skipping MSI build." -ForegroundColor DarkGray
}

$fileSize = (Get-Item $zipPath).Length / 1MB
$sha256 = (Get-FileHash $zipPath -Algorithm SHA256).Hash

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " Release package created successfully!" -ForegroundColor Green
Write-Host " Archive: $zipPath" -ForegroundColor Green
Write-Host " Size: $([Math]::Round($fileSize, 2)) MB" -ForegroundColor Green
Write-Host " SHA256: $sha256" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Save checksum file
Set-Content -Path "$distDir\AnimeWallpaper-$Version-win-x64.zip.sha256" -Value "$sha256  AnimeWallpaper-$Version-win-x64.zip"

if ($CreateGitHubRelease) {
    Write-Host "--> Creating GitHub Release via GitHub CLI..." -ForegroundColor Yellow
    $assets = @($zipPath)
    if (Test-Path $msiPath) { $assets += $msiPath }
    gh release create $Version $assets `
        --title "Anime Wallpaper $Version" `
        --generate-notes
    Write-Host "--> GitHub Release $Version created!" -ForegroundColor Green
}
