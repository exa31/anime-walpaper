import Foundation

public final class StartupService {
    public static let shared = StartupService()

    private let launchAgentLabel = "com.antigravity.animewallpaper"

    private var launchAgentFile: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let agentsDir = home.appendingPathComponent("Library/LaunchAgents")
        try? FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        return agentsDir.appendingPathComponent("\(launchAgentLabel).plist")
    }

    public func isEnabled() -> Bool {
        return FileManager.default.fileExists(atPath: launchAgentFile.path)
    }

    public func setEnabled(_ enable: Bool) {
        if enable {
            let bundleUrl = Bundle.main.bundleURL
            let executablePath: String

            if bundleUrl.pathExtension == "app" {
                executablePath = bundleUrl.path
            } else {
                executablePath = Bundle.main.executablePath ?? CommandLine.arguments[0]
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
                    <string>\(executablePath)</string>
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
            } catch {
                Logger.error("Failed to enable start at login", error: error)
            }
        } else {
            if FileManager.default.fileExists(atPath: launchAgentFile.path) {
                try? FileManager.default.removeItem(at: launchAgentFile)
                Logger.info("Removed startup LaunchAgent at \(launchAgentFile.path)")
            }
        }
    }
}
