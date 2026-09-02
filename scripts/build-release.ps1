<#
.SYNOPSIS
    Builds and packages Anime Wallpaper into a self-contained Windows executable and ZIP release.
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

$rootDir = Split-Path -Parent $PSScriptRoot
$distDir = Join-Path $rootDir "dist"
$publishDir = Join-Path $distDir "AnimeWallpaper"
$zipPath = Join-Path $distDir "AnimeWallpaper-$Version-win-x64.zip"

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
    gh release create $Version $zipPath `
        --title "Anime Wallpaper $Version" `
        --generate-notes
    Write-Host "--> GitHub Release $Version created!" -ForegroundColor Green
}
