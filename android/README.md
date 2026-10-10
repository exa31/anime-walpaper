# 📱 Anime Wallpaper for Android

Native Android application built with **Kotlin** and **Jetpack Compose**, bringing the Anime Wallpaper experience to Android smartphones with deep battery and network optimizations.

---

## ✨ Mobile Optimizations & Features

- 🔋 **Jetpack WorkManager Background Rotation**:
  - Compliant with Android Doze Mode and Battery Saver policies.
  - Periodic background rotation without heavy persistent foreground services.
- 📶 **Wi-Fi Only Data Guard**:
  - Toggle to restrict background downloads to unmetered Wi-Fi connections, preventing mobile data drainage.
- 📱 **Portrait Aspect Ratio Auto-Filter**:
  - Automatically queries Wallhaven with portrait ratios (`9x16, 10x16, 9x18, 9x19.5`) to eliminate awkward landscape crops on mobile screens.
- 🖼️ **On-Demand Full Download & WebP Thumbnails**:
  - Uses Coil to load lightweight WebP thumbnails in the UI, fetching full 2K/4K high-res images only when actively applied or exported.
- 🎯 **Target Chooser**:
  - Apply wallpaper specifically to **Home Screen**, **Lock Screen**, or **Both**.
- 📥 **Save to Device**:
  - Direct 1-tap export to system Photos / Gallery (`Pictures/AnimeWallpapers`).

---

## 🛠️ Building & Running

### Requirements
- Android Studio Hedgehog (2023.1.1) or newer
- JDK 17
- Android SDK Platform 34 (Android 14)
- Minimum SDK: Android 8.0 (API 26)

### Build APK via CLI
```bash
cd android
./gradlew assembleDebug

# Output APK:
# android/app/build/outputs/apk/debug/app-debug.apk
```

### Install to connected device / emulator
```bash
adb install android/app/build/outputs/apk/debug/app-debug.apk
```
