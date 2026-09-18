import Foundation

public final class ConfigService: @unchecked Sendable {
    public static let shared = ConfigService()
    private let lock = NSRecursiveLock()

    public var configDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AnimeWallpaper")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var configFile: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    private var stateFile: URL {
        configDirectory.appendingPathComponent("state.json")
    }

    public func loadConfig() -> AppConfig {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: configFile.path),
              let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            let defaultConfig = AppConfig()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(defaultConfig) {
                try? data.write(to: configFile, options: .atomic)
            }
            return defaultConfig
        }
        return config
    }

    public func saveConfig(_ config: AppConfig) {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config) {
            try? data.write(to: configFile, options: .atomic)
        }
        Logger.shared.setApiKeyToMask(config.wallhavenApiKey)
    }

    public func loadState() -> AppState {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: stateFile.path),
              let data = try? Data(contentsOf: stateFile),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else {
            return AppState()
        }
        return state
    }

    public func saveState(_ state: AppState) {
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(state) {
            try? data.write(to: stateFile, options: .atomic)
        }
    }
}
