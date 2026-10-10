# 🐧 Anime Wallpaper for Linux (CLI & Daemon)

Ultra-lightweight background wallpaper rotator and CLI utility for Linux desktops powered by .NET 8 and Wallhaven API.

---

## ✨ Features

- 🖥️ **Desktop Environment Auto-Detection**:
  - Automatically identifies and supports:
    - **GNOME / Budgie / Cinnamon / Unity**: via `gsettings` (`picture-uri` & `picture-uri-dark`)
    - **KDE Plasma 5 & 6**: via `plasma-apply-wallpaperimage` or DBus scripting
    - **XFCE**: via `xfconf-query`
    - **Hyprland / Sway / Wayland**: via `hyprctl hyprpaper`, `swww`, or `swaymsg`
    - **X11 Standalone**: via `feh` or `nitrogen`
- ⚙️ **Custom Wallpaper Command**:
  - Support for custom wallpaper setters (e.g., `swww img {file}`) configurable in `~/.config/AnimeWallpaper/config.json`.
- 🔄 **Systemd User Service Integration**:
  - One-command setup (`anime-wallpaper --install-service`) to run as a persistent, low-overhead background service managed by `systemd --user`.
- 🧹 **Smart LRU Cache**:
  - Auto-evicts old wallpapers while strictly preserving the currently active wallpaper.
- 🪵 **Secure Logging**:
  - Automatically redacts and masks API keys in console outputs.

---

## 🚀 Usage & Commands

```bash
# Fetch and apply next anime wallpaper immediately
anime-wallpaper --next

# Start the continuous background rotator daemon
anime-wallpaper --daemon

# Check status, active wallpaper, and cache details
anime-wallpaper --status

# Change search query or category
anime-wallpaper --query "landscape anime"

# Set rotation interval to 60 minutes
anime-wallpaper --interval 60

# Install as systemd auto-start background service
anime-wallpaper --install-service

# Uninstall systemd service
anime-wallpaper --uninstall-service
```

---

## 🛠️ Building & Packaging

### Requirements
- .NET 8 SDK

```bash
# Build self-contained single-file binary:
./linux/scripts/build-linux.sh 1.0.0

# The compiled binary will be placed at:
# dist/linux/anime-wallpaper
```
