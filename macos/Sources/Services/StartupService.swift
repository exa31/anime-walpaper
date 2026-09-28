import Foundation

public final class StartupService {
    public static let shared = StartupService()

    private let launchAgentLabel = "com.antigravity.animewallpaper"
    private let appName = "Anime Wallpaper"

    private var launchAgentFile: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let agentsDir = home.appendingPathComponent("Library/LaunchAgents")
        try? FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        return agentsDir.appendingPathComponent("\(launchAgentLabel).plist")
    }

    public func isEnabled() -> Bool {
        if isLoginItemRegistered() {
            return true
        }
        return FileManager.default.fileExists(atPath: launchAgentFile.path)
    }

    public func setEnabled(_ enable: Bool) {
        let bundleUrl = Bundle.main.bundleURL
        let isAppBundle = bundleUrl.pathExtension == "app"
        let appPath = isAppBundle ? bundleUrl.path : (Bundle.main.executablePath ?? CommandLine.arguments[0])

        if enable {
            // 1. Register as native macOS Login Item if running from .app bundle
            if isAppBundle {
                registerLoginItem(appPath: appPath)
            }

            // 2. Also write LaunchAgent plist (with proper /usr/bin/open for .app bundles)
            writeLaunchAgent(appPath: appPath, isAppBundle: isAppBundle)
        } else {
            // 1. Remove from macOS Login Items
            unregisterLoginItem(appPath: appPath)

            // 2. Remove LaunchAgent plist
            removeLaunchAgent()
        }
    }

    // MARK: - macOS Login Items (System Events)

    private func runAppleScript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            Logger.error("Failed to run AppleScript", error: error)
            return nil
        }
    }

    private func isLoginItemRegistered() -> Bool {
        let script = "tell application \"System Events\" to return exists (login items whose name is \"\(appName)\")"
        return runAppleScript(script) == "true"
    }

    private func registerLoginItem(appPath: String) {
        if isLoginItemRegistered() {
            Logger.info("Login item '\(appName)' already registered.")
            return
        }
        let escapedPath = appPath.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"System Events\" to make login item at end with properties {path:\"\(escapedPath)\", hidden:false, name:\"\(appName)\"}"
        _ = runAppleScript(script)
        Logger.info("Registered '\(appName)' to macOS Login Items.")
    }

    private func unregisterLoginItem(appPath: String) {
        let escapedPath = appPath.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"System Events\" to delete (every login item whose name is \"\(appName)\" or path is \"\(escapedPath)\")"
        _ = runAppleScript(script)
        Logger.info("Removed '\(appName)' from macOS Login Items.")
    }

    // MARK: - LaunchAgent Plist Fallback

    private func writeLaunchAgent(appPath: String, isAppBundle: Bool) {
        let programArgs: String
        if isAppBundle {
            programArgs = """
                    <string>/usr/bin/open</string>
                    <string>-g</string>
                    <string>-a</string>
                    <string>\(appPath)</string>
            """
        } else {
            programArgs = """
                    <string>\(appPath)</string>
            """
        }

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentLabel)</string>
            <key>ProgramArguments</key>
            <array>
        \(programArgs)
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """

        do {
            try plistContent.write(to: launchAgentFile, atomically: true, encoding: .utf8)
            Logger.info("Registered startup LaunchAgent at \(launchAgentFile.path)")
            _ = runCommand("/bin/launchctl", arguments: ["unload", launchAgentFile.path])
            _ = runCommand("/bin/launchctl", arguments: ["load", launchAgentFile.path])
        } catch {
            Logger.error("Failed to write LaunchAgent plist", error: error)
        }
    }

    private func removeLaunchAgent() {
        if FileManager.default.fileExists(atPath: launchAgentFile.path) {
            _ = runCommand("/bin/launchctl", arguments: ["unload", launchAgentFile.path])
            try? FileManager.default.removeItem(at: launchAgentFile)
            Logger.info("Removed startup LaunchAgent at \(launchAgentFile.path)")
        }
    }

    private func runCommand(_ executable: String, arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
