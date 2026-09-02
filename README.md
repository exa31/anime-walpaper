# 🌸 Anime Wallpaper

[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)
[![.NET 8](https://img.shields.io/badge/.NET-8.0-blue.svg)](https://dotnet.microsoft.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6.svg)](https://microsoft.com/windows)
[![Release](https://img.shields.io/github/v/release/exa31/anime-walpaper?color=green&include_prereleases)](https://github.com/exa31/anime-walpaper/releases)

A modern, lightweight Windows desktop application that automatically fetches and rotates stunning anime wallpapers directly from the **Wallhaven API** to your desktop background at configurable intervals. Runs smoothly in the Windows System Tray with zero performance overhead.

---

## ✨ Features

- 🔄 **Automatic Wallpaper Rotation**: Fetches high-resolution anime wallpapers on a periodic schedule (5m, 15m, 30m, 1h, 2h, 6h, 12h) or immediately via the "Next Wallpaper" button.
- 🖼️ **Live Preview & Metadata**: Displays current wallpaper thumbnail, Wallhaven ID, resolution, last changed timestamp, and file size.
- 🎯 **Preset Query Chips**: Quick one-click category presets (`anime`, `anime girl`, `cyberpunk anime`, `landscape anime`, `studio ghibli`, `nature anime`, `makoto shinkai`) or enter any custom search tags.
- 🛡️ **SFW & Resolution Filtering**: Guarantees family-safe wallpapers (`purity=100`) and lets you set minimum desktop resolutions (e.g. 1920×1080, 2560×1440, 3840×2160).
- 📥 **Smart Cache Management**: Saves wallpapers into `%USERPROFILE%\Pictures\AnimeWallpapers`. Keeps up to a configurable limit (default 20), automatically purging the oldest cached images while strictly preserving the currently active wallpaper.
- 🔔 **Windows System Tray & Notifications**: Closes to the System Tray to keep your taskbar clean. Includes a right-click tray menu (Next Wallpaper, Pause/Resume, Open Settings, Open Cache, Exit) and sends balloon tip notifications when a new wallpaper is applied.
- 🚀 **Auto-Start With Windows**: Toggle automatic startup at login via `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` without requiring administrator privileges.
- 🪵 **Safe Rolling Logging**: Logs rotation events and errors to `%LOCALAPPDATA%\AnimeWallpaper\logs\` while automatically masking your API key.
- ⚡ **Self-Contained Executable**: Single portable `.exe` ready to run on Windows 10 & 11 without needing any pre-installed .NET runtimes.

---

## 📥 Download & Installation

### Option 1: Pre-built Executable (Recommended)
1. Go to the [**GitHub Releases**](https://github.com/exa31/anime-wallpaper/releases) page.
2. Download `AnimeWallpaper-v1.0.0-win-x64.zip`.
3. Extract the ZIP to any folder (e.g. `C:\Program Files\AnimeWallpaper` or `%LOCALAPPDATA%\Programs\AnimeWallpaper`).
4. Run `AnimeWallpaper.exe`.

### Option 2: Build from Source
Ensure [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) is installed on your Windows machine.

```powershell
# Clone the repository
git clone https://github.com/exa31/anime-walpaper.git
cd "anime-walpaper"

# Restore and run in development mode
dotnet restore
dotnet run
```

---

## 🛠️ Build & Publishing

### Build Debug / Release DLLs
```powershell
dotnet build -c Release
```

### Publish Standalone Self-Contained `.exe`
```powershell
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o ./dist/publish
```
The output file `./dist/publish/AnimeWallpaper.exe` is completely self-contained and ready to be distributed.

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
