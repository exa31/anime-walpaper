# 🍏 Anime Wallpaper for iOS

Native iOS application built with **Swift** & **SwiftUI**, bringing Wallhaven anime art curation, interactive Lock/Home Screen mock previews, and automated background wallpaper rotation via **Apple Siri Shortcuts**.

---

## ✨ Key Features & iOS Innovations

- 🪄 **Apple Siri Shortcuts Automation**:
  - Provides a native `AppIntent` (`FetchNextAnimeWallpaperIntent`) and `AppShortcutsProvider`.
  - Enables background wallpaper rotation triggered by iOS Automations (e.g. daily time of day, connecting to charger, or focus mode).
- 📱 **Interactive Lock Screen & Home Screen Overlays**:
  - Switch between *Raw*, *Lock Screen* (clock & widgets), and *Home Screen* (app icons) inside the app to see exactly how artwork looks behind your actual UI before applying.
- 📐 **Mobile Portrait Ratio Filtering**:
  - Queries Wallhaven with portrait aspect ratios (`9x16, 10x16, 9x18, 9x19.5`) to ensure pristine framing on iPhone Super Retina displays.
- 💾 **1-Tap Save to Camera Roll**:
  - Seamlessly saves full-resolution wallpapers to Apple Photos with `PHPhotoLibrary`.
- ⚡ **Zero Background Battery Drain**:
  - Zero persistent background daemons—relies purely on native iOS Shortcuts events.

---

## 🛠️ Building & Running

### Requirements
- macOS 14.0 or newer with Xcode 15+
- iOS 16.0+ deployment target

### Setup with Xcode
1. Open Xcode.
2. Create or open the iOS project pointing to `ios/AnimeWallpaperiOS`.
3. Select your target iPhone or iOS Simulator.
4. Press `Cmd + R` to build and run.

---

## ⏰ How to Set Up Automated Daily Rotation on iPhone

1. Open the built-in **Shortcuts** app on your iPhone.
2. Tap the **Automation** tab at the bottom, then tap **+** (New Automation).
3. Select **Time of Day** (e.g. 08:00 AM) or **When Charger is Connected**.
4. Choose **Run Immediately** (toggle off *Notify When Run* for silent updates).
5. Add action: Search for **Anime Wallpaper** → choose **Get Next Anime Wallpaper**.
6. Add action: Search for **Set Wallpaper** → link the photo result from step 5 to Lock Screen & Home Screen.
7. Tap **Done**! Your iPhone wallpaper will now automatically rotate in the background.
