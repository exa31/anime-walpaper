import Foundation

public struct AppConfig: Codable {
    public var query: String
    public var sfwOnly: Bool
    public var isRandom: Bool
    public var apiKey: String
    public var maxCachedWallpapers: Int

    public init(
        query: String = "anime",
        sfwOnly: Bool = true,
        isRandom: Bool = true,
        apiKey: String = "",
        maxCachedWallpapers: Int = 15
    ) {
        self.query = query
        self.sfwOnly = sfwOnly
        self.isRandom = isRandom
        self.apiKey = apiKey
        self.maxCachedWallpapers = maxCachedWallpapers
    }
}
