import Foundation
import SwiftUI
import Combine
import ImageIO
import AppKit

@MainActor
public final class WallpaperViewModel: ObservableObject {
    @Published public var config: AppConfig
    @Published public var state: AppState
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String = "Ready"
    @Published public var cachedCount: Int = 0
    @Published public var currentPreviewImage: NSImage? = nil

    public var nextRotationDate: Date?

    private let wallhavenService: WallhavenServiceProtocol
    private let wallpaperService: WallpaperServiceProtocol
    private let configService: ConfigService
    private let startupService: StartupService
    private let notificationService: NotificationService

    private var rotationTimer: Timer?
    private var screenSyncTask: Task<Void, Never>?

    public static let presetQueries = [
        "anime",
        "anime girl",
        "cyberpunk anime",
        "landscape anime",
        "studio ghibli",
        "nature anime",
        "makoto shinkai"
    ]

    public init(
        wallhavenService: WallhavenServiceProtocol = WallhavenService(),
        wallpaperService: WallpaperServiceProtocol = WallpaperService(),
        configService: ConfigService = .shared,
        startupService: StartupService = .shared,
        notificationService: NotificationService = .shared
    ) {
        self.wallhavenService = wallhavenService
        self.wallpaperService = wallpaperService
        self.configService = configService
        self.startupService = startupService
        self.notificationService = notificationService

        self.config = configService.loadConfig()
        self.state = configService.loadState()

        self.cachedCount = wallpaperService.getCachedCount()

        // Sync startup setting with actual system startup state
        if config.startWithMac {
            if !startupService.isEnabled() {
                startupService.setEnabled(true)
            }
        } else {
            self.config.startWithMac = startupService.isEnabled()
        }

        // Load preview thumbnail and reapply saved wallpaper across screens on app launch
        if !state.currentWallpaperPath.isEmpty && FileManager.default.fileExists(atPath: state.currentWallpaperPath) {
            loadPreviewImage(from: state.currentWallpaperPath)

            Task { @MainActor [weak self] in
                // Small buffer to allow macOS WindowServer and external displays to settle
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                self?.reapplyCurrentWallpaper()
            }
        }

        // Reapply wallpaper when screen parameters/monitors connect or disconnect
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScreenConfigurationChange()
            }
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter

        workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScreenConfigurationChange()
            }
        }

        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScreenConfigurationChange()
            }
        }

        scheduleRotationTimer()

        // Initial wallpaper fetch if no wallpaper is set yet
        if state.currentWallpaperPath.isEmpty || !FileManager.default.fileExists(atPath: state.currentWallpaperPath) {
            Task {
                await rotateWallpaper(force: false)
            }
        }
    }

    public func saveConfig() {
        configService.saveConfig(config)
        startupService.setEnabled(config.startWithMac)
        scheduleRotationTimer()
    }

    public func selectPresetQuery(_ query: String) {
        config.query = query
        saveConfig()
        Task {
            await rotateWallpaper(force: true)
        }
    }

    public func togglePause() {
        state.isPaused.toggle()
        configService.saveState(state)
        if state.isPaused {
            statusMessage = "Paused"
            nextRotationDate = nil
            rotationTimer?.invalidate()
            rotationTimer = nil
        } else {
            statusMessage = "Resumed"
            scheduleRotationTimer()
        }
    }

    public func nextWallpaper() {
        Task {
            await rotateWallpaper(force: true)
        }
    }

    public func rotateWallpaper(force: Bool) async {
        guard !isLoading else { return }
        if !force && state.isPaused {
            Logger.info("Rotation skipped: App is paused.")
            return
        }

        isLoading = true
        statusMessage = "Searching Wallhaven..."

        do {
            let items = try await wallhavenService.searchWallpapers(config: config)
            if items.isEmpty {
                statusMessage = "No wallpapers found"
                isLoading = false
                return
            }

            // Filter out recently used IDs
            var candidate = items.first { !state.usedWallpaperIds.contains($0.id) }
            if candidate == nil {
                Logger.info("All returned wallpapers recently used. Resetting history pool.")
                state.usedWallpaperIds.removeAll()
                candidate = items.randomElement()
            }

            guard let selected = candidate else {
                statusMessage = "No suitable wallpaper found"
                isLoading = false
                return
            }

            statusMessage = "Downloading Wallhaven #\(selected.id)..."
            let imagePath = await wallpaperService.downloadWallpaper(id: selected.id, imageUrl: selected.path)

            guard let filePath = imagePath else {
                statusMessage = "Download failed"
                isLoading = false
                return
            }

            statusMessage = "Setting desktop wallpaper..."
            let applied = wallpaperService.setDesktopWallpaper(filePath: filePath)

            if applied {
                let res = selected.resolution ?? "\(selected.dimensionX ?? 0)x\(selected.dimensionY ?? 0)"
                state.addUsedId(selected.id)
                state.currentWallpaperId = selected.id
                state.currentWallpaperPath = filePath
                state.currentResolution = res
                state.lastChanged = Date()

                configService.saveState(state)
                wallpaperService.pruneCache(maxWallpapers: config.maxCachedWallpapers, currentWallpaperPath: filePath)
                cachedCount = wallpaperService.getCachedCount()

                // Efficiently downsample and update cached thumbnail preview
                loadPreviewImage(from: filePath)

                if config.showNotifications {
                    notificationService.sendWallpaperNotification(id: selected.id, resolution: res)
                }

                statusMessage = "Updated to #\(selected.id)"
            } else {
                statusMessage = "Failed to apply wallpaper"
            }
        } catch {
            Logger.error("Failed rotating wallpaper", error: error)
            statusMessage = "Error: \(error.localizedDescription)"
        }

        isLoading = false
        scheduleRotationTimer()
    }

    public func openCacheFolder() {
        wallpaperService.openCacheFolder()
    }

    public func clearCache() {
        wallpaperService.clearCache(currentWallpaperPath: state.currentWallpaperPath)
        cachedCount = wallpaperService.getCachedCount()
    }

    public func openWallhavenPage() {
        guard !state.currentWallpaperId.isEmpty,
              let url = URL(string: "https://wallhaven.cc/w/\(state.currentWallpaperId)") else { return }
        NSWorkspace.shared.open(url)
    }

    public func reapplyCurrentWallpaper() {
        guard !state.currentWallpaperPath.isEmpty,
              FileManager.default.fileExists(atPath: state.currentWallpaperPath) else { return }
        Logger.info("Re-applying wallpaper across screens on display/screen configuration change.")
        _ = wallpaperService.setDesktopWallpaper(filePath: state.currentWallpaperPath)
    }

    public func handleScreenConfigurationChange() {
        let screens = NSScreen.screens
        Logger.info("Screen configuration change detected. Active display count: \(screens.count)")

        screenSyncTask?.cancel()
        screenSyncTask = Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.reapplyCurrentWallpaper()

            // Negotiate external screen reconnection buffer
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            self.reapplyCurrentWallpaper()
        }
    }

    public func revealCurrentInFinder() {
        guard !state.currentWallpaperPath.isEmpty,
              FileManager.default.fileExists(atPath: state.currentWallpaperPath) else { return }
        NSWorkspace.shared.selectFile(state.currentWallpaperPath, inFileViewerRootedAtPath: "")
    }

    public func loadPreviewImage(from path: String) {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            self.currentPreviewImage = nil
            return
        }

        Task.detached(priority: .userInitiated) {
            let fileURL = URL(fileURLWithPath: path)
            let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, imageSourceOptions) else {
                return
            }

            let maxDimensionInPixels: CGFloat = 640
            let downsampleOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
            ] as [CFString: Any] as CFDictionary

            guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
                return
            }

            let thumbnail = NSImage(cgImage: downsampledImage, size: NSSize(width: downsampledImage.width, height: downsampledImage.height))
            await MainActor.run { [weak self] in
                self?.currentPreviewImage = thumbnail
            }
        }
    }

    public func getNextRotationText(at date: Date = Date()) -> String {
        if state.isPaused {
            return "Paused"
        }
        guard let target = nextRotationDate else {
            return "Calculating..."
        }

        let remaining = Int(target.timeIntervalSince(date))
        if remaining <= 0 {
            return "Rotating soon..."
        } else {
            let m = remaining / 60
            let s = remaining % 60
            if m >= 60 {
                let h = m / 60
                let remM = m % 60
                return "\(h)h \(remM)m"
            } else {
                return String(format: "%02d:%02d", m, s)
            }
        }
    }

    private func scheduleRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = nil

        guard !state.isPaused else { return }
        let minutes = max(1, config.intervalMinutes)
        let interval = TimeInterval(minutes * 60)
        nextRotationDate = Date().addingTimeInterval(interval)

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.rotateWallpaper(force: false)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        rotationTimer = timer
    }
}
