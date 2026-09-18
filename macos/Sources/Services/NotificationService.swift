import Foundation
import UserNotifications
import AppKit

public final class NotificationService {
    public static let shared = NotificationService()

    private init() {
        requestAuthorization()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                Logger.warn("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    public func sendWallpaperNotification(id: String, resolution: String) {
        // Try UNUserNotificationCenter first
        let content = UNMutableNotificationContent()
        content.title = "Wallpaper Updated 🌸"
        content.body = "Wallhaven #\(id) (\(resolution))"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                // Fallback to AppleScript notification if app bundle is unsigned or unbundled in dev
                let scriptSource = """
                display notification "Wallhaven #\(id) (\(resolution))" with title "Anime Wallpaper 🌸"
                """
                if let script = NSAppleScript(source: scriptSource) {
                    var scriptError: NSDictionary?
                    script.executeAndReturnError(&scriptError)
                }
            }
        }
    }
}
