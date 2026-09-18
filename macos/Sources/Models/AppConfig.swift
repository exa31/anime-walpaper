import Foundation

public struct AppConfig: Codable, Equatable {
    public var wallhavenApiKey: String
    public var query: String
    public var intervalMinutes: Int
    public var minimumWidth: Int
    public var minimumHeight: Int
    public var sfwOnly: Bool
    public var random: Bool
    public var startWithMac: Bool
    public var maxCachedWallpapers: Int
    public var showNotifications: Bool

    public init(
        wallhavenApiKey: String = "",
        query: String = "anime",
        intervalMinutes: Int = 30,
        minimumWidth: Int = 1920,
        minimumHeight: Int = 1080,
        sfwOnly: Bool = true,
        random: Bool = true,
        startWithMac: Bool = false,
        maxCachedWallpapers: Int = 20,
        showNotifications: Bool = true
    ) {
        self.wallhavenApiKey = wallhavenApiKey
        self.query = query
        self.intervalMinutes = intervalMinutes
        self.minimumWidth = minimumWidth
        self.minimumHeight = minimumHeight
        self.sfwOnly = sfwOnly
        self.random = random
        self.startWithMac = startWithMac
        self.maxCachedWallpapers = maxCachedWallpapers
        self.showNotifications = showNotifications
    }
}
