import Foundation

public protocol WallhavenServiceProtocol: Sendable {
    func searchWallpapers(config: AppConfig) async throws -> [WallhavenItem]
}

public final class WallhavenService: WallhavenServiceProtocol, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func searchWallpapers(config: AppConfig) async throws -> [WallhavenItem] {
        let query = config.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "anime" : config.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let categories = "010" // Anime only
        let purity = config.sfwOnly ? "100" : "110" // 100 = SFW
        let sorting = config.random ? "random" : "toplist"
        let minW = config.minimumWidth > 0 ? config.minimumWidth : 1920
        let minH = config.minimumHeight > 0 ? config.minimumHeight : 1080
        let atleast = "\(minW)x\(minH)"

        var components = URLComponents(string: "https://wallhaven.cc/api/v1/search")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "categories", value: categories),
            URLQueryItem(name: "purity", value: purity),
            URLQueryItem(name: "sorting", value: sorting),
            URLQueryItem(name: "atleast", value: atleast)
        ]

        let apiKey = config.wallhavenApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            Logger.error("Failed to construct Wallhaven search URL")
            return []
        }

        Logger.info("Requesting Wallhaven: q='\(query)', categories=\(categories), purity=\(purity), sorting=\(sorting), atleast=\(atleast)")

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("AnimeWallpaperMac/1.0", forHTTPHeaderField: "User-Agent")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.warn("Wallhaven returned non-HTTP response")
            return []
        }

        if httpResponse.statusCode == 429 {
            Logger.warn("Wallhaven API rate limit hit (HTTP 429). Will retry next cycle.")
            return []
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            Logger.warn("Wallhaven API returned error status: \(httpResponse.statusCode)")
            return []
        }

        let decoded = try JSONDecoder().decode(WallhavenResponse.self, from: data)
        guard let items = decoded.data, !items.isEmpty else {
            Logger.warn("Wallhaven API returned 0 results for query '\(query)'")
            return []
        }

        Logger.info("Wallhaven returned \(items.count) wallpapers.")
        return items
    }
}
