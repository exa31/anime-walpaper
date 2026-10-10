# 🌸 Anime Wallpaper

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android%20%7C%20iOS-0078D6.svg)](https://github.com/exa31/anime-walpaper)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Kotlin](https://img.shields.io/badge/Kotlin-Compose-7F52FF.svg)](https://kotlinlang.org)
[![.NET 8](https://img.shields.io/badge/.NET-8.0-blue.svg)](https://dotnet.microsoft.com/)
[![Release](https://img.shields.io/github/v/release/exa31/anime-walpaper?color=green&include_prereleases)](https://github.com/exa31/anime-walpaper/releases)

A modern, ultra-lightweight anime wallpaper rotator for **Windows**, **macOS**, **Linux**, **Android**, and **iOS** that automatically fetches and rotates stunning anime wallpapers directly from the **Wallhaven API** at configurable intervals. Runs smoothly across desktop system trays/menu bars and mobile operating systems with deep battery, memory, and data optimizations.

---

## ✨ Features

- 🔄 **Automatic Wallpaper Rotation**: Fetches high-resolution anime wallpapers on a periodic schedule (5m, 15m, 30m, 1h, 2h, 6h, 12h) or immediately via the "Next Wallpaper" button.
- 🖼️ **Live Preview & Metadata**: Displays current wallpaper thumbnail, Wallhaven ID, resolution, last changed timestamp, and file size.
- 🎯 **Preset Query Chips**: Quick one-click category presets (`anime`, `anime girl`, `cyberpunk anime`, `landscape anime`, `studio ghibli`, `nature anime`, `makoto shinkai`) or enter any custom search tags.
- 🛡️ **SFW & Resolution Filtering**: Guarantees family-safe wallpapers (`purity=100`) and lets you set minimum desktop resolutions (e.g. 1920×1080, 2560×1440, 3840×2160).
- 📥 **Smart Cache Management**: Saves wallpapers into `%USERPROFILE%\Pictures\AnimeWallpapers` (Windows) or `~/Pictures/AnimeWallpapers` (macOS). Keeps up to a configurable limit (default 20), automatically purging the oldest cached images while strictly preserving the currently active wallpaper.
- 🔔 **System Tray & Menu Bar Integration**: 
  - **macOS**: Native SwiftUI Menu Bar app with frosted-glass popover window, zero Dock clutter (`LSUIElement`), and native Cocoa wallpaper switching.
  - **Windows**: Closes to the System Tray with right-click context menu and balloon tip notifications.
- 🚀 **Auto-Start at Login**: Toggle automatic startup (Windows Registry / macOS LaunchAgent) without requiring administrator privileges.
- 🪵 **Safe Rolling Logging**: Logs rotation events and errors while automatically masking your API key.

---

## 🍏 macOS Usage & Build

### Running / Building on macOS
The macOS version is built in native **Swift & SwiftUI** and requires macOS 13.0 or newer.

```bash
# 1. Build and package into Anime Wallpaper.app
./scripts/build-macos.sh 1.0.0

# 2. Open the app
open "dist/macos/Anime Wallpaper.app"
```

The app icon (`🌸` / `✨`) will appear in your top Menu Bar. Click it to view the live preview, rotate wallpapers, choose preset query chips, or configure settings.

---

## 🪟 Windows Usage & Build

### Option 1: Pre-built Executable (Windows)
1. Go to the [**GitHub Releases**](https://github.com/exa31/anime-walpaper/releases) page.
2. Download `AnimeWallpaper-v1.0.0-win-x64.zip`.
3. Extract and run `AnimeWallpaper.exe`.

### Option 2: Build from Source (.NET 8 SDK)
```powershell
# Restore and run in development mode
dotnet restore
dotnet run

# Publish Standalone Self-Contained .exe
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o ./dist/publish
```


### Automated Packaging Script
Run the automated packaging script in PowerShell to produce a ready-to-release ZIP archive with SHA256 checksums:
```powershell
.\scripts\build-release.ps1 -Version "v1.0.0"
```

To automatically create a GitHub Release using the GitHub CLI (`gh`):
```powershell
.\scripts\build-release.ps1 -Version "v1.0.0" -CreateGitHubRelease
```

---

## 🐧 Linux Usage & Daemon

The Linux version is an ultra-lightweight CLI/Daemon built with **.NET 8** that auto-detects your Desktop Environment (GNOME, KDE Plasma, XFCE, Sway, Hyprland, feh).

```bash
# 1. Fetch & apply next wallpaper immediately
anime-wallpaper --next

# 2. Run as continuous background daemon
anime-wallpaper --daemon

# 3. Register as auto-start systemd user service
anime-wallpaper --install-service
```

---

## 📱 Android Usage & Build (Kotlin & Jetpack Compose)

The native Android app lives in [`android/`](file:///Users/macbookair/projects/anime-walpaper/android/README.md).
- **Background Engine**: Powered by Jetpack `WorkManager` (Doze & battery-friendly, unmetered Wi-Fi constraints).
- **Mobile Optimized**: Auto-filters portrait ratios (`9x16, 10x16, 9x18`), loads WebP thumbnails with Coil, and downloads full-res on demand.
- **Targets**: Apply to Home Screen, Lock Screen, or Both.

```bash
cd android
./gradlew assembleDebug
```

---

## 🍏 iOS Usage & Siri Shortcuts (Swift & SwiftUI)

The native iOS app lives in [`ios/`](file:///Users/macbookair/projects/anime-walpaper/ios/README.md).
- **Apple Siri Shortcuts**: Uses `AppIntent` (`FetchNextAnimeWallpaperIntent`) so iOS Automations can automatically rotate wallpapers at scheduled times or triggers without background battery drain.
- **Interactive Mock Overlays**: Live preview raw artwork, Lock Screen (clock & widgets), or Home Screen (app grid).
- **Save to Photos**: Direct 1-tap export via `PHPhotoLibrary`.

---

## 🔑 Wallhaven API Key Setup

Anime Wallpaper works **out of the box without an API key** using Wallhaven's public search endpoint.

If you have a Wallhaven account and want higher rate limits or access to your personalized collections:
1. Log in to [Wallhaven](https://wallhaven.cc).
2. Navigate to **Settings** → **API**.
3. Copy your API Key.
4. In Anime Wallpaper UI, expand **Wallhaven API Key & Cache Options**, paste your key, and click **Save Settings**.
5. Alternatively, edit `%LOCALAPPDATA%\AnimeWallpaper\config.json`:
   ```json
   {
     "wallhavenApiKey": "your_api_key_here"
   }
   ```

> [!NOTE]
> Your API key is stored locally in your user profile and is **never printed to logs**.

---

## 📂 File Locations

| Item | Path |
| :--- | :--- |
| **Configuration** | `%LOCALAPPDATA%\AnimeWallpaper\config.json` |
| **State (History)** | `%LOCALAPPDATA%\AnimeWallpaper\state.json` |
| **Application Logs** | `%LOCALAPPDATA%\AnimeWallpaper\logs\app-yyyyMMdd.log` |
| **Wallpaper Cache** | `%USERPROFILE%\Pictures\AnimeWallpapers\` |

---

## ⚙️ Configuration Schema (`config.json`)

```json
{
  "wallhavenApiKey": "",
  "query": "anime",
  "intervalMinutes": 30,
  "minimumWidth": 1920,
  "minimumHeight": 1080,
  "sfwOnly": true,
  "random": true,
  "startWithWindows": true,
  "maxCachedWallpapers": 20,
  "showNotifications": true
}
```

---

## 🖱️ System Tray Controls

- **Double-click Tray Icon**: Opens and brings the Settings window to the front.
- **Right-click Tray Menu**:
  - **Anime Wallpaper**: Header indicator
  - **Status**: Displays current state (Running / Paused / Downloading)
  - **Next Wallpaper**: Triggers immediate wallpaper search and switch
  - **Pause / Resume**: Suspends or resumes automatic rotation
  - **Open Settings**: Opens main control window
  - **Open Cache Folder**: Opens `%USERPROFILE%\Pictures\AnimeWallpapers`
  - **Exit**: Completely shuts down the application and removes the tray icon

---

## 🧹 Uninstalling

1. Open Anime Wallpaper settings and uncheck **Start with Windows** (removes the registry auto-start entry).
2. Right-click the system tray icon and choose **Exit**.
3. Delete the following folders if you want a 100% clean uninstall:
   - `%LOCALAPPDATA%\AnimeWallpaper\` (removes config, state, and logs)
   - `%USERPROFILE%\Pictures\AnimeWallpapers\` (removes downloaded wallpaper cache)
   - The directory where `AnimeWallpaper.exe` was placed.

---

## 🔍 Troubleshooting

| Issue | Resolution |
| :--- | :--- |
| **Status says "Connection failed"** | Verify your internet connection. Wallhaven may temporarily be under maintenance or rate-limiting requests. The app will automatically retry on the next interval. |
| **Status says "Rate limit hit (429)"** | Wallhaven enforces rate limits when too many requests are sent in a short burst. Wait 1-2 minutes or provide a free Wallhaven API key in settings. |
| **Wallpaper doesn't change on dual monitors** | Windows sets the primary monitor's wallpaper via `SystemParametersInfo`. In Windows 10/11 Settings → Personalization → Background, make sure "Choose a fit" is set to "Fill". |
| **Window disappears when closed** | This is the intended behavior! The app minimizes to the Windows System Tray (next to the clock). Click the tray arrow `^` to locate the icon. |

---

## 📄 License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.
Contributions and pull requests are welcome!
