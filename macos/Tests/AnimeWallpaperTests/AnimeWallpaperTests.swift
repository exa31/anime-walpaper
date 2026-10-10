import XCTest
import Foundation

final class AnimeWallpaperTests: XCTestCase {

    func testWallhavenResponseJSONParsing() throws {
        let jsonString = """
        {
          "data": [
            {
              "id": "test_id_101",
              "url": "https://wallhaven.cc/w/test_id_101",
              "purity": "100",
              "category": "anime",
              "resolution": "2560x1440",
              "ratio": "16:9",
              "file_size": 1024000,
              "file_type": "image/jpeg",
              "path": "https://w.wallhaven.cc/full/te/wallhaven-test_id_101.jpg"
            }
          ],
          "meta": {
            "current_page": 1,
            "last_page": 5,
            "per_page": 1,
            "total": 5
          }
        }
        """

        struct WallhavenItemMini: Codable {
            let id: String
            let url: String
            let purity: String
            let resolution: String
            let path: String
        }

        struct WallhavenResponseMini: Codable {
            let data: [WallhavenItemMini]
        }

        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(WallhavenResponseMini.self, from: data)

        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "test_id_101")
        XCTAssertEqual(response.data[0].purity, "100")
        XCTAssertEqual(response.data[0].resolution, "2560x1440")
    }

    func testPathTraversalPreventionOnWallpaperId() {
        func isValidWallpaperId(_ id: String) -> Bool {
            let pattern = "^[a-zA-Z0-9_-]{1,64}$"
            return id.range(of: pattern, options: .regularExpression) != nil
        }

        XCTAssertTrue(isValidWallpaperId("wallhaven_abc123"))
        XCTAssertTrue(isValidWallpaperId("anime-girl-4k"))
        XCTAssertFalse(isValidWallpaperId("../etc/passwd"))
        XCTAssertFalse(isValidWallpaperId("../../root"))
        XCTAssertFalse(isValidWallpaperId("id;rm -rf"))
        XCTAssertFalse(isValidWallpaperId(""))
    }

    func testUrlSchemeAndHostWhitelisting() {
        func isWhitelistedUrl(_ urlString: String) -> Bool {
            guard let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  let host = url.host?.lowercased() else {
                return false
            }

            guard scheme == "https" else { return false }
            return host == "wallhaven.cc" || host.hasSuffix(".wallhaven.cc")
        }

        XCTAssertTrue(isWhitelistedUrl("https://w.wallhaven.cc/full/12/wallhaven-123.jpg"))
        XCTAssertTrue(isWhitelistedUrl("https://wallhaven.cc/api/v1/search"))
        XCTAssertFalse(isWhitelistedUrl("http://w.wallhaven.cc/full/12/image.jpg")) // Non-HTTPS
        XCTAssertFalse(isWhitelistedUrl("file:///Users/secrets.txt"))
        XCTAssertFalse(isWhitelistedUrl("https://malicious.com/image.jpg"))
        XCTAssertFalse(isWhitelistedUrl("https://127.0.0.1/exploit"))
    }

    func testApiKeyMaskingInLogs() {
        func sanitizeLogMessage(_ message: String, apiKey: String?) -> String {
            var result = message
            if let key = apiKey, !key.isEmpty {
                result = result.replacingOccurrences(of: key, with: "[REDACTED_API_KEY]")
            }

            // Regex for apikey= in query strings
            let queryRegex = try! NSRegularExpression(pattern: "(?i)(apikey[=:])\\s*([a-zA-Z0-9_\\-]+)")
            result = queryRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "$1[REDACTED_API_KEY]"
            )
            return result
        }

        let rawLog = "GET https://wallhaven.cc/api/v1/search?q=anime&apikey=superSecretToken123"
        let sanitized = sanitizeLogMessage(rawLog, apiKey: "superSecretToken123")

        XCTAssertFalse(sanitized.contains("superSecretToken123"))
        XCTAssertTrue(sanitized.contains("apikey=[REDACTED_API_KEY]"))
    }
}
