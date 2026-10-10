import Foundation

public final class WallhavenService {
    public static let shared = WallhavenService()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.httpAdditionalHeaders = ["User-Agent": "AnimeWallpaperiOS/1.0"]
        self.session = URLSession(configuration: configuration)
    }

    public func searchWallpapers(config: AppConfig) async throws -> [WallhavenItem] {
        let query = config.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "anime" : config.query
        let categories = "010" // Anime only
        let purity = config.sfwOnly ? "100" : "110"
        let sorting = config.isRandom ? "random" : "toplist"
        let ratios = "9x16,10x16,9x18,9x19.5" // Portrait optimization for iPhone screens

        var components = URLComponents(string: "https://wallhaven.cc/api/v1/search")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "categories", value: categories),
            URLQueryItem(name: "purity", value: purity),
            URLQueryItem(name: "sorting", value: sorting),
            URLQueryItem(name: "ratios", value: ratios)
        ]

        if !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        components.queryItems = queryItems
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        if !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.addValue(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "X-API-Key")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { return [] }

        if httpResponse.statusCode == 429 {
            print("⚠️ Wallhaven API rate limit reached (HTTP 429).")
            return []
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("⚠️ Wallhaven returned status \(httpResponse.statusCode)")
            return []
        }

        let decoded = try JSONDecoder().decode(WallhavenResponse.self, from: data)
        return decoded.data ?? []
    }
}
