import Foundation

public struct AppState: Codable {
    public var usedWallpaperIds: [String]
    public var currentWallpaperId: String
    public var currentWallpaperPath: String
    public var currentResolution: String
    public var lastChanged: Date?
    public var isPaused: Bool

    public init(
        usedWallpaperIds: [String] = [],
        currentWallpaperId: String = "",
        currentWallpaperPath: String = "",
        currentResolution: String = "",
        lastChanged: Date? = nil,
        isPaused: Bool = false
    ) {
        self.usedWallpaperIds = usedWallpaperIds
        self.currentWallpaperId = currentWallpaperId
        self.currentWallpaperPath = currentWallpaperPath
        self.currentResolution = currentResolution
        self.lastChanged = lastChanged
        self.isPaused = isPaused
    }

    public mutating func addUsedId(_ id: String, maxTracked: Int = 200) {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        usedWallpaperIds.removeAll { $0 == id }
        usedWallpaperIds.append(id)
        if usedWallpaperIds.count > maxTracked {
            usedWallpaperIds.removeFirst(usedWallpaperIds.count - maxTracked)
        }
    }
}
