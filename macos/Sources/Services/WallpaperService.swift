import Foundation
import AppKit

public protocol WallpaperServiceProtocol: Sendable {
    var cacheDirectory: URL { get }
    func downloadWallpaper(id: String, imageUrl: String) async -> String?
    func setDesktopWallpaper(filePath: String) -> Bool
    func pruneCache(maxWallpapers: Int, currentWallpaperPath: String?)
    func clearCache(currentWallpaperPath: String?)
    func openCacheFolder()
    func getCachedCount() -> Int
}

public final class WallpaperService: WallpaperServiceProtocol, @unchecked Sendable {
    private let session: URLSession

    public var cacheDirectory: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let dir = pictures.appendingPathComponent("AnimeWallpapers")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func downloadWallpaper(id: String, imageUrl: String) async -> String? {
        guard let remoteUrl = URL(string: imageUrl) else {
            Logger.error("Invalid wallpaper URL: \(imageUrl)")
            return nil
        }

        var ext = remoteUrl.pathExtension.lowercased()
        if ext.isEmpty || (ext != "png" && ext != "jpg" && ext != "jpeg") {
            ext = "jpg"
        }

        let targetFileName = "wallhaven-\(id).\(ext)"
        let targetFile = cacheDirectory.appendingPathComponent(targetFileName)

        // Check if file already exists in cache with valid size (>10KB)
        if FileManager.default.fileExists(atPath: targetFile.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: targetFile.path),
               let size = attrs[.size] as? Int64, size > 10240 {
                Logger.info("Wallpaper already in cache: \(targetFileName)")
                return targetFile.path
            }
        }

        Logger.info("Downloading wallpaper \(id) from \(imageUrl)...")
        let tempFile = cacheDirectory.appendingPathComponent("temp_\(UUID().uuidString).tmp")

        do {
            let (tempLocation, response) = try await session.download(from: remoteUrl)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                Logger.error("Download failed with non-200 HTTP response for wallpaper \(id)")
                return nil
            }

            // Move from system temp to our tempFile
            if FileManager.default.fileExists(atPath: tempFile.path) {
                try? FileManager.default.removeItem(at: tempFile)
            }
            try FileManager.default.moveItem(at: tempLocation, to: tempFile)

            let attrs = try FileManager.default.attributesOfItem(atPath: tempFile.path)
            let size = attrs[.size] as? Int64 ?? 0
            if size < 10240 {
                Logger.warn("Downloaded file too small (\(size) bytes). Discarding.")
                try? FileManager.default.removeItem(at: tempFile)
                return nil
            }

            if FileManager.default.fileExists(atPath: targetFile.path) {
                try? FileManager.default.removeItem(at: targetFile)
            }
            try FileManager.default.moveItem(at: tempFile, to: targetFile)

            // Ensure file has 0644 permissions so WallpaperAgent and WindowServer can read it
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: targetFile.path)

            Logger.info("Successfully cached wallpaper \(id) (\(size / 1024) KB) -> \(targetFileName)")
            return targetFile.path
        } catch {
            Logger.error("Error downloading wallpaper \(id) from \(imageUrl)", error: error)
            try? FileManager.default.removeItem(at: tempFile)
            return nil
        }
    }

    public func setDesktopWallpaper(filePath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: filePath) else {
            Logger.error("Cannot set desktop wallpaper: file does not exist at \(filePath)")
            return false
        }

        // Guarantee 0644 permissions before applying
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: filePath)

        let fileUrl = URL(fileURLWithPath: filePath)
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true
        ]

        var anySuccess = false
        let screens = NSScreen.screens
        Logger.info("Applying wallpaper to \(screens.count) screen(s): \(filePath)")

        for (index, screen) in screens.enumerated() {
            do {
                try NSWorkspace.shared.setDesktopImageURL(fileUrl, for: screen, options: options)
                
                // Verify that macOS applied it; if not, retry with default options
                let currentURL = NSWorkspace.shared.desktopImageURL(for: screen)
                if currentURL?.path != fileUrl.path {
                    Logger.warn("Screen \(index) [\(screen.localizedName)] URL mismatch, retrying without options...")
                    try NSWorkspace.shared.setDesktopImageURL(fileUrl, for: screen, options: [:])
                }
                
                Logger.info("Successfully set wallpaper on Screen \(index) [\(screen.localizedName)]")
                anySuccess = true
            } catch {
                Logger.error("Failed to set wallpaper on Screen \(index) [\(screen.localizedName)]", error: error)
            }
        }

        if anySuccess {
            Logger.info("Desktop wallpaper update completed.")
        } else {
            Logger.error("Failed to set desktop wallpaper on any screen.")
        }

        return anySuccess
    }

    public func pruneCache(maxWallpapers: Int, currentWallpaperPath: String?) {
        guard maxWallpapers > 0 else { return }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: .skipsHiddenFiles)
            let imageFiles = files.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "webp"].contains(ext)
            }

            guard imageFiles.count > maxWallpapers else { return }

            let sorted = imageFiles.sorted { u1, u2 in
                let d1 = (try? u1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return d1 < d2 // Oldest first
            }

            var toRemove = imageFiles.count - maxWallpapers
            for file in sorted {
                if toRemove <= 0 { break }
                if let current = currentWallpaperPath, file.path == current {
                    continue // Strictly preserve current wallpaper!
                }
                try? FileManager.default.removeItem(at: file)
                Logger.info("Pruned old wallpaper cache: \(file.lastPathComponent)")
                toRemove -= 1
            }
        } catch {
            Logger.error("Failed to prune wallpaper cache", error: error)
        }
    }

    public func clearCache(currentWallpaperPath: String?) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for file in files {
                if let current = currentWallpaperPath, file.path == current {
                    continue
                }
                try? FileManager.default.removeItem(at: file)
            }
            Logger.info("Cache cleared (active wallpaper preserved).")
        } catch {
            Logger.error("Failed to clear cache", error: error)
        }
    }

    public func openCacheFolder() {
        NSWorkspace.shared.open(cacheDirectory)
    }

    public func getCachedCount() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return 0
        }
        return files.filter { ["jpg", "jpeg", "png", "webp"].contains($0.pathExtension.lowercased()) }.count
    }
}
