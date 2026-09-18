import Foundation
import SwiftUI
import Combine

@MainActor
public final class WallpaperViewModel: ObservableObject {
    @Published public var config: AppConfig
    @Published public var state: AppState
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String = "Ready"
    @Published public var cachedCount: Int = 0
    @Published public var nextRotationText: String = ""

    private let wallhavenService: WallhavenServiceProtocol
    private let wallpaperService: WallpaperServiceProtocol
    private let configService: ConfigService
    private let startupService: StartupService
    private let notificationService: NotificationService

    private var rotationTimer: Timer?
    private var countdownTimer: Timer?
    private var nextRotationDate: Date?

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

        // Sync startup setting with actual LaunchAgent state
        self.config.startWithMac = startupService.isEnabled()

        scheduleRotationTimer()
        startCountdownTimer()

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
            nextRotationText = "Paused"
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

    public func revealCurrentInFinder() {
        guard !state.currentWallpaperPath.isEmpty,
              FileManager.default.fileExists(atPath: state.currentWallpaperPath) else { return }
        NSWorkspace.shared.selectFile(state.currentWallpaperPath, inFileViewerRootedAtPath: "")
    }

    private func scheduleRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = nil

        guard !state.isPaused else { return }
        let minutes = max(1, config.intervalMinutes)
        let interval = TimeInterval(minutes * 60)
        nextRotationDate = Date().addingTimeInterval(interval)

        rotationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.rotateWallpaper(force: false)
            }
        }
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCountdown()
            }
        }
    }

    private func updateCountdown() {
        if state.isPaused {
            nextRotationText = "Paused"
            return
        }
        guard let target = nextRotationDate else {
            nextRotationText = "Calculating..."
            return
        }

        let remaining = Int(target.timeIntervalSinceNow)
        if remaining <= 0 {
            nextRotationText = "Rotating soon..."
        } else {
            let m = remaining / 60
            let s = remaining % 60
            if m >= 60 {
                let h = m / 60
                let remM = m % 60
                nextRotationText = "\(h)h \(remM)m"
            } else {
                nextRotationText = String(format: "%02d:%02d", m, s)
            }
        }
    }
}
