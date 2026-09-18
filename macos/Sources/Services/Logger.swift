import Foundation
import AppKit

public final class Logger: @unchecked Sendable {
    public static let shared = Logger()
    private let lock = NSLock()
    private var configuredApiKey: String?

    public var logDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AnimeWallpaper/logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func setApiKeyToMask(_ key: String?) {
        lock.lock()
        defer { lock.unlock() }
        configuredApiKey = key
    }

    public static func info(_ message: String) {
        shared.log(level: "INFO", message: message)
    }

    public static func warn(_ message: String) {
        shared.log(level: "WARN", message: message)
    }

    public static func error(_ message: String, error: Error? = nil) {
        let fullMessage = error == nil ? message : "\(message) | Error: \(error!.localizedDescription)"
        shared.log(level: "ERROR", message: fullMessage)
    }

    private func log(level: String, message: String) {
        var sanitized = message
        lock.lock()
        if let key = configuredApiKey, key.count >= 4 {
            sanitized = sanitized.replacingOccurrences(of: key, with: "***API_KEY_HIDDEN***")
        }
        lock.unlock()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let line = "\(timestamp) [\(level)] \(sanitized)\n"

        print(line, terminator: "")

        lock.lock()
        defer { lock.unlock() }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyyMMdd"
        let logFile = logDirectory.appendingPathComponent("app-\(dayFormatter.string(from: Date())).log")

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFile, options: .atomic)
            }
        }
    }

    public static func openLogFolder() {
        NSWorkspace.shared.open(shared.logDirectory)
    }
}
