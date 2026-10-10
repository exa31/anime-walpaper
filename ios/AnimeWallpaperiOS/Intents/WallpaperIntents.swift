import Foundation
import AppIntents
import UIKit

@available(iOS 16.0, *)
public struct FetchNextAnimeWallpaperIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Next Anime Wallpaper"
    public static var description = IntentDescription("Fetches high-resolution portrait anime wallpaper from Wallhaven for Shortcuts wallpaper automation.")

    @Parameter(title: "Search Query", default: "anime")
    public var query: String

    @Parameter(title: "SFW Only", default: true)
    public var sfwOnly: Bool

    public static var parameterSummary: some ParameterSummary {
        Summary("Fetch next anime wallpaper with query \(\.$query)")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let config = AppConfig(query: query, sfwOnly: sfwOnly)
        let items = try await WallhavenService.shared.searchWallpapers(config: config)

        guard let selected = items.randomElement(),
              let url = URL(string: selected.path) else {
            throw NSError(domain: "AnimeWallpaperIntent", code: 404, userInfo: [NSLocalizedDescriptionKey: "No wallpapers found."])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("anime_\(selected.id).jpg")
        try data.write(to: tempUrl)

        let file = IntentFile(fileURL: tempUrl, filename: "anime_\(selected.id).jpg")
        return .result(value: file)
    }
}

@available(iOS 16.0, *)
public struct AnimeShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FetchNextAnimeWallpaperIntent(),
            phrases: [
                "Get next anime wallpaper in \(.applicationName)",
                "Rotate wallpaper with \(.applicationName)"
            ],
            shortTitle: "Next Anime Wallpaper",
            systemImageName: "sparkles"
        )
    }
}
