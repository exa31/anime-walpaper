using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;

namespace AnimeWallpaper.Linux.Services;

public class LinuxWallpaperService
{
    private readonly HttpClient _httpClient;

    public string CacheDirectory
    {
        get
        {
            var pictures = Environment.GetFolderPath(Environment.SpecialFolder.MyPictures);
            if (string.IsNullOrWhiteSpace(pictures) || !Directory.Exists(pictures))
            {
                var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                pictures = Path.Combine(home, "Pictures");
            }
            return Path.Combine(pictures, "AnimeWallpapers");
        }
    }

    public string CurrentWallpaperTrackerPath => Path.Combine(
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".config", "AnimeWallpaper"),
        "current_wallpaper.txt"
    );

    public LinuxWallpaperService(HttpClient? httpClient = null)
    {
        _httpClient = httpClient ?? new HttpClient();
    }

    public string? GetCurrentWallpaper()
    {
        try
        {
            if (File.Exists(CurrentWallpaperTrackerPath))
            {
                var path = File.ReadAllText(CurrentWallpaperTrackerPath).Trim();
                if (File.Exists(path)) return path;
            }
        }
        catch { }
        return null;
    }

    public void SaveCurrentWallpaper(string filePath)
    {
        try
        {
            var dir = Path.GetDirectoryName(CurrentWallpaperTrackerPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
            File.WriteAllText(CurrentWallpaperTrackerPath, filePath);
        }
        catch { }
    }

    public static bool IsValidWallpaperId(string id)
    {
        if (string.IsNullOrWhiteSpace(id)) return false;
        // Strictly alphanumeric and dashes/underscores (prevent path traversal like ../../)
        return System.Text.RegularExpressions.Regex.IsMatch(id, "^[a-zA-Z0-9_-]{1,64}$");
    }

    public static bool IsValidWallpaperUrl(string url)
    {
        if (string.IsNullOrWhiteSpace(url)) return false;
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri)) return false;
        // Strict HTTPS and domain whitelist (wallhaven.cc / w.wallhaven.cc)
        if (uri.Scheme != Uri.UriSchemeHttps) return false;
        return uri.Host.Equals("wallhaven.cc", StringComparison.OrdinalIgnoreCase) ||
               uri.Host.EndsWith(".wallhaven.cc", StringComparison.OrdinalIgnoreCase);
    }

    public static bool IsSafeCustomCommand(string command)
    {
        if (string.IsNullOrWhiteSpace(command)) return false;
        if (!command.Contains("{file}")) return false;

        // Block dangerous command chaining / execution injection metacharacters
        var forbiddenPatterns = new[] { ";", "&&", "||", "`", "$(", ">", "<", "\n", "\r" };
        foreach (var pattern in forbiddenPatterns)
        {
            if (command.Contains(pattern)) return false;
        }
        return true;
    }

    public async Task<string?> DownloadWallpaperAsync(string id, string imageUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            if (!IsValidWallpaperId(id))
            {
                Logger.Error($"Security warning: Invalid wallpaper ID detected '{id}'. Possible path traversal attempt.");
                return null;
            }

            if (!IsValidWallpaperUrl(imageUrl))
            {
                Logger.Error($"Security warning: Blocked unauthorized or non-HTTPS wallpaper URL: {imageUrl}");
                return null;
            }

            if (!Directory.Exists(CacheDirectory))
            {
                Directory.CreateDirectory(CacheDirectory);
            }

            var ext = Path.GetExtension(new Uri(imageUrl).AbsolutePath);
            if (string.IsNullOrWhiteSpace(ext) || (!ext.Equals(".png", StringComparison.OrdinalIgnoreCase) && !ext.Equals(".jpg", StringComparison.OrdinalIgnoreCase) && !ext.Equals(".jpeg", StringComparison.OrdinalIgnoreCase)))
            {
                ext = ".jpg";
            }

            var fileName = $"wallhaven_{id}{ext}";
            var destinationPath = Path.Combine(CacheDirectory, fileName);

            // Path Traversal containment check
            var fullCacheDir = Path.GetFullPath(CacheDirectory) + Path.DirectorySeparatorChar;
            var fullDestPath = Path.GetFullPath(destinationPath);
            if (!fullDestPath.StartsWith(fullCacheDir, StringComparison.OrdinalIgnoreCase) &&
                !fullDestPath.Equals(Path.GetFullPath(CacheDirectory), StringComparison.OrdinalIgnoreCase))
            {
                Logger.Error($"Security warning: Target file path escapes cache directory: {destinationPath}");
                return null;
            }

            if (File.Exists(destinationPath))
            {
                Logger.Info($"Wallpaper already cached: {fileName}");
                return destinationPath;
            }

            Logger.Info($"Downloading wallpaper: {imageUrl}");

            using var response = await _httpClient.GetAsync(imageUrl, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            response.EnsureSuccessStatusCode();

            var tempPath = destinationPath + ".tmp";
            await using (var fileStream = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                await response.Content.CopyToAsync(fileStream, cancellationToken);
            }

            if (File.Exists(destinationPath))
            {
                File.Delete(destinationPath);
            }
            File.Move(tempPath, destinationPath);

            var sizeInMb = new FileInfo(destinationPath).Length / (1024.0 * 1024.0);
            Logger.Success($"Saved wallpaper to {destinationPath} ({sizeInMb:F2} MB)");
            return destinationPath;
        }
        catch (OperationCanceledException)
        {
            Logger.Info("Download cancelled.");
            return null;
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to download wallpaper from {imageUrl}", ex);
            return null;
        }
    }

    public bool SetDesktopWallpaper(string filePath, string? customCommand = null)
    {
        if (!File.Exists(filePath))
        {
            Logger.Error($"Cannot set wallpaper: file not found at {filePath}");
            return false;
        }

        var fullPath = Path.GetFullPath(filePath);

        // Custom command has highest precedence
        if (!string.IsNullOrWhiteSpace(customCommand))
        {
            if (!IsSafeCustomCommand(customCommand))
            {
                Logger.Error($"Security warning: Custom wallpaper command rejected due to dangerous or invalid metacharacters: {customCommand}");
                return false;
            }
            var cmd = customCommand.Replace("{file}", $"\"{fullPath}\"");
            Logger.Info($"Executing custom wallpaper command: {cmd}");
            return RunShellCommand(cmd);
        }

        var desktop = (Environment.GetEnvironmentVariable("XDG_CURRENT_DESKTOP") ?? "").ToUpperInvariant();
        var session = (Environment.GetEnvironmentVariable("DESKTOP_SESSION") ?? "").ToUpperInvariant();
        var isWayland = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("WAYLAND_DISPLAY"));

        Logger.Info($"Detected Desktop Environment: '{desktop}', Session: '{session}', Wayland: {isWayland}");

        // 1. GNOME / Cinnamon / Budgie / Unity
        if (desktop.Contains("GNOME") || desktop.Contains("CINNAMON") || desktop.Contains("BUDGIE") || desktop.Contains("UNITY"))
        {
            var uri = $"file://{fullPath}";
            bool ok1 = RunProcess("gsettings", $"set org.gnome.desktop.background picture-uri \"{uri}\"");
            bool ok2 = RunProcess("gsettings", $"set org.gnome.desktop.background picture-uri-dark \"{uri}\"");
            RunProcess("gsettings", "set org.gnome.desktop.background picture-options 'zoom'");
            if (ok1 || ok2)
            {
                SaveCurrentWallpaper(fullPath);
                return true;
            }
        }

        // 2. KDE Plasma
        if (desktop.Contains("KDE") || desktop.Contains("PLASMA"))
        {
            if (CommandExists("plasma-apply-wallpaperimage"))
            {
                if (RunProcess("plasma-apply-wallpaperimage", $"\"{fullPath}\""))
                {
                    SaveCurrentWallpaper(fullPath);
                    return true;
                }
            }

            // Fallback via DBus script
            var kdeScript = $"var allDesktops = desktops();for (i=0;i<allDesktops.length;i++) {{d = allDesktops[i];d.wallpaperPlugin = 'org.kde.image';d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');d.writeConfig('Image', 'file://{fullPath}');}}";
            if (RunProcess("qdbus", $"org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \"{kdeScript}\""))
            {
                SaveCurrentWallpaper(fullPath);
                return true;
            }
        }

        // 3. XFCE
        if (desktop.Contains("XFCE"))
        {
            if (RunProcess("xfconf-query", $"-c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s \"{fullPath}\""))
            {
                SaveCurrentWallpaper(fullPath);
                return true;
            }
        }

        // 4. Hyprland / Sway / Wayland compositors
        if (desktop.Contains("HYPRLAND"))
        {
            if (CommandExists("hyprctl"))
            {
                RunProcess("hyprctl", $"hyprpaper preload \"{fullPath}\"");
                if (RunProcess("hyprctl", $"hyprpaper wallpaper \",{fullPath}\""))
                {
                    SaveCurrentWallpaper(fullPath);
                    return true;
                }
            }
            if (CommandExists("swww"))
            {
                if (RunProcess("swww", $"img \"{fullPath}\" --transition-type wipe --transition-fps 60"))
                {
                    SaveCurrentWallpaper(fullPath);
                    return true;
                }
            }
        }

        if (desktop.Contains("SWAY"))
        {
            if (CommandExists("swaymsg"))
            {
                if (RunProcess("swaymsg", $"output \"*\" bg \"{fullPath}\" fill"))
                {
                    SaveCurrentWallpaper(fullPath);
                    return true;
                }
            }
        }

        // 5. Wayland generic (swww)
        if (isWayland && CommandExists("swww"))
        {
            if (RunProcess("swww", $"img \"{fullPath}\" --transition-type wipe --transition-fps 60"))
            {
                SaveCurrentWallpaper(fullPath);
                return true;
            }
        }

        // 6. X11 generic fallbacks (feh / nitrogen)
        if (CommandExists("feh"))
        {
            if (RunProcess("feh", $"--bg-fill \"{fullPath}\""))
            {
                SaveCurrentWallpaper(fullPath);
                return true;
            }
        }

        if (CommandExists("nitrogen"))
        {
            if (RunProcess("nitrogen", $"--set-zoom-fill \"{fullPath}\" --save"))
            {
                SaveCurrentWallpaper(fullPath);
                return true;
            }
        }

        Logger.Warn("No supported desktop environment or wallpaper setter tool (feh, swww, plasma-apply-wallpaperimage, gsettings) could be invoked successfully.");
        return false;
    }

    public void PruneCache(int maxWallpapers, string? currentWallpaperPath)
    {
        try
        {
            if (!Directory.Exists(CacheDirectory)) return;

            var dir = new DirectoryInfo(CacheDirectory);
            var files = dir.GetFiles()
                .Where(f => f.Extension.Equals(".jpg", StringComparison.OrdinalIgnoreCase) ||
                            f.Extension.Equals(".png", StringComparison.OrdinalIgnoreCase) ||
                            f.Extension.Equals(".jpeg", StringComparison.OrdinalIgnoreCase))
                .OrderBy(f => f.LastAccessTimeUtc)
                .ToList();

            if (files.Count <= maxWallpapers) return;

            var toRemoveCount = files.Count - maxWallpapers;
            var removed = 0;

            foreach (var file in files)
            {
                if (removed >= toRemoveCount) break;

                // Never delete the currently active wallpaper
                if (currentWallpaperPath != null &&
                    string.Equals(file.FullName, Path.GetFullPath(currentWallpaperPath), StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                try
                {
                    file.Delete();
                    removed++;
                    Logger.Info($"LRU Cache pruned: {file.Name}");
                }
                catch { }
            }
        }
        catch (Exception ex)
        {
            Logger.Warn($"Failed to prune wallpaper cache: {ex.Message}");
        }
    }

    public int GetCachedCount()
    {
        try
        {
            if (!Directory.Exists(CacheDirectory)) return 0;
            return new DirectoryInfo(CacheDirectory).GetFiles()
                .Count(f => f.Extension.Equals(".jpg", StringComparison.OrdinalIgnoreCase) ||
                            f.Extension.Equals(".png", StringComparison.OrdinalIgnoreCase) ||
                            f.Extension.Equals(".jpeg", StringComparison.OrdinalIgnoreCase));
        }
        catch
        {
            return 0;
        }
    }

    public void ClearCache(string? currentWallpaperPath)
    {
        try
        {
            if (!Directory.Exists(CacheDirectory)) return;

            var files = new DirectoryInfo(CacheDirectory).GetFiles();
            foreach (var file in files)
            {
                if (currentWallpaperPath != null &&
                    string.Equals(file.FullName, Path.GetFullPath(currentWallpaperPath), StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                try { file.Delete(); } catch { }
            }
            Logger.Success("Cached wallpapers cleared.");
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to clear cache", ex);
        }
    }

    private static bool CommandExists(string command)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "which",
                Arguments = command,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using var proc = Process.Start(psi);
            proc?.WaitForExit();
            return proc?.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }

    private static bool RunProcess(string program, string arguments)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = program,
                Arguments = arguments,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using var proc = Process.Start(psi);
            proc?.WaitForExit();
            return proc?.ExitCode == 0;
        }
        catch (Exception ex)
        {
            Logger.Warn($"Command '{program} {arguments}' failed to execute: {ex.Message}");
            return false;
        }
    }

    private static bool RunShellCommand(string command)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "/bin/sh",
                Arguments = $"-c \"{command.Replace("\"", "\\\"")}\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            using var proc = Process.Start(psi);
            proc?.WaitForExit();
            return proc?.ExitCode == 0;
        }
        catch (Exception ex)
        {
            Logger.Warn($"Shell command failed: {ex.Message}");
            return false;
        }
    }
}
