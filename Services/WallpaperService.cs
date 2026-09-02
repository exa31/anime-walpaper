using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;

namespace AnimeWallpaper.Services;

public interface IWallpaperService
{
    string CacheDirectory { get; }
    Task<string?> DownloadWallpaperAsync(string id, string imageUrl, CancellationToken cancellationToken = default);
    bool SetDesktopWallpaper(string filePath);
    void PruneCache(int maxWallpapers, string? currentWallpaperPath);
    void ClearCache(string? currentWallpaperPath);
    void OpenCacheFolder();
    int GetCachedCount();
}

public class WallpaperService : IWallpaperService
{
    private const int SPI_SETDESKWALLPAPER = 0x0014;
    private const int SPIF_UPDATEINIFILE = 0x01;
    private const int SPIF_SENDCHANGE = 0x02;

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);

    private readonly HttpClient _httpClient;

    public string CacheDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.MyPictures),
        "AnimeWallpapers"
    );

    public WallpaperService(HttpClient? httpClient = null)
    {
        _httpClient = httpClient ?? new HttpClient();
    }

    public async Task<string?> DownloadWallpaperAsync(string id, string imageUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            if (!Directory.Exists(CacheDirectory))
            {
                Directory.CreateDirectory(CacheDirectory);
            }

            // Determine file extension
            var ext = Path.GetExtension(new Uri(imageUrl).AbsolutePath);
            if (string.IsNullOrWhiteSpace(ext) || (!ext.Equals(".png", StringComparison.OrdinalIgnoreCase) && !ext.Equals(".jpg", StringComparison.OrdinalIgnoreCase) && !ext.Equals(".jpeg", StringComparison.OrdinalIgnoreCase)))
            {
                ext = ".jpg";
            }

            var targetFileName = $"wallhaven-{id}{ext}";
            var targetFilePath = Path.Combine(CacheDirectory, targetFileName);

            // If file already exists and valid size, reuse
            if (File.Exists(targetFilePath))
            {
                var fileInfo = new FileInfo(targetFilePath);
                if (fileInfo.Length > 10240) // > 10KB
                {
                    Logger.Info($"Wallpaper already in cache: {targetFileName}");
                    return targetFilePath;
                }
            }

            Logger.Info($"Downloading wallpaper {id} from {imageUrl}");

            var tempFilePath = Path.Combine(CacheDirectory, $"temp_{Guid.NewGuid():N}.tmp");

            using (var response = await _httpClient.GetAsync(imageUrl, HttpCompletionOption.ResponseHeadersRead, cancellationToken))
            {
                response.EnsureSuccessStatusCode();

                using (var stream = await response.Content.ReadAsStreamAsync(cancellationToken))
                using (var fileStream = new FileStream(tempFilePath, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    await stream.CopyToAsync(fileStream, cancellationToken);
                }
            }

            // Verify file length
            var tempFileInfo = new FileInfo(tempFilePath);
            if (tempFileInfo.Length < 10240)
            {
                Logger.Warn($"Downloaded file for wallpaper {id} is too small ({tempFileInfo.Length} bytes). Discarding.");
                File.Delete(tempFilePath);
                return null;
            }

            // Atomically replace target file
            if (File.Exists(targetFilePath))
            {
                File.Delete(targetFilePath);
            }
            File.Move(tempFilePath, targetFilePath);

            Logger.Info($"Successfully cached wallpaper {id} ({tempFileInfo.Length / 1024} KB) to {targetFileName}");
            return targetFilePath;
        }
        catch (OperationCanceledException)
        {
            Logger.Info($"Download of wallpaper {id} was cancelled.");
            return null;
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to download wallpaper {id} from {imageUrl}", ex);
            return null;
        }
    }

    public bool SetDesktopWallpaper(string filePath)
    {
        try
        {
            if (!File.Exists(filePath))
            {
                Logger.Error($"Cannot set wallpaper. File does not exist: {filePath}");
                return false;
            }

            // Configure registry for Fill mode (10 = Fill, 0 = Tile)
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop", true);
                if (key != null)
                {
                    key.SetValue("WallpaperStyle", "10"); // Fill
                    key.SetValue("TileWallpaper", "0");
                }
            }
            catch (Exception ex)
            {
                Logger.Warn($"Could not update Desktop registry style: {ex.Message}");
            }

            // Call SystemParametersInfo
            int result = SystemParametersInfo(
                SPI_SETDESKWALLPAPER,
                0,
                filePath,
                SPIF_UPDATEINIFILE | SPIF_SENDCHANGE
            );

            if (result != 0)
            {
                Logger.Info($"Desktop wallpaper applied successfully: {Path.GetFileName(filePath)}");
                return true;
            }
            else
            {
                int errorCode = Marshal.GetLastWin32Error();
                Logger.Error($"SystemParametersInfo returned 0. Win32 Error code: {errorCode}");
                return false;
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to set desktop wallpaper: {filePath}", ex);
            return false;
        }
    }

    public void PruneCache(int maxWallpapers, string? currentWallpaperPath)
    {
        try
        {
            if (!Directory.Exists(CacheDirectory) || maxWallpapers <= 0)
                return;

            var dir = new DirectoryInfo(CacheDirectory);
            var files = dir.GetFiles("wallhaven-*.*")
                .OrderBy(f => f.LastWriteTimeUtc)
                .ToList();

            if (files.Count <= maxWallpapers)
                return;

            int toDelete = files.Count - maxWallpapers;
            int deleted = 0;

            foreach (var file in files)
            {
                if (deleted >= toDelete) break;

                // Never delete the currently active wallpaper!
                if (!string.IsNullOrEmpty(currentWallpaperPath) &&
                    string.Equals(file.FullName, currentWallpaperPath, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                try
                {
                    file.Delete();
                    deleted++;
                    Logger.Info($"Pruned old wallpaper from cache: {file.Name}");
                }
                catch (Exception ex)
                {
                    Logger.Warn($"Could not delete cache file {file.Name}: {ex.Message}");
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Error("Error pruning wallpaper cache", ex);
        }
    }

    public void ClearCache(string? currentWallpaperPath)
    {
        try
        {
            if (!Directory.Exists(CacheDirectory)) return;

            var dir = new DirectoryInfo(CacheDirectory);
            var files = dir.GetFiles("wallhaven-*.*");
            int deleted = 0;

            foreach (var file in files)
            {
                if (!string.IsNullOrEmpty(currentWallpaperPath) &&
                    string.Equals(file.FullName, currentWallpaperPath, StringComparison.OrdinalIgnoreCase))
                {
                    continue; // Skip current
                }

                try
                {
                    file.Delete();
                    deleted++;
                }
                catch
                {
                    // Ignore busy files
                }
            }

            Logger.Info($"Cleared wallpaper cache. Deleted {deleted} files.");
        }
        catch (Exception ex)
        {
            Logger.Error("Error clearing wallpaper cache", ex);
        }
    }

    public void OpenCacheFolder()
    {
        try
        {
            if (!Directory.Exists(CacheDirectory))
            {
                Directory.CreateDirectory(CacheDirectory);
            }
            Process.Start(new ProcessStartInfo
            {
                FileName = CacheDirectory,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to open cache directory", ex);
        }
    }

    public int GetCachedCount()
    {
        try
        {
            if (!Directory.Exists(CacheDirectory)) return 0;
            return Directory.GetFiles(CacheDirectory, "wallhaven-*.*").Length;
        }
        catch
        {
            return 0;
        }
    }
}
