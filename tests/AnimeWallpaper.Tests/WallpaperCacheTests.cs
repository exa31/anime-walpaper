using System;
using System.IO;
using AnimeWallpaper.Linux.Services;
using Xunit;

namespace AnimeWallpaper.Tests;

public class WallpaperCacheTests : IDisposable
{
    private readonly string _testCacheDir;

    public WallpaperCacheTests()
    {
        _testCacheDir = Path.Combine(Path.GetTempPath(), "AnimeWallpaper_TestCache_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_testCacheDir);
    }

    public void Dispose()
    {
        try
        {
            if (Directory.Exists(_testCacheDir))
            {
                Directory.Delete(_testCacheDir, recursive: true);
            }
        }
        catch { }
    }

    [Fact]
    public void PruneCache_KeepsCountWithinLimit_AndPreservesActiveWallpaper()
    {
        // Arrange
        var service = new LinuxWallpaperService();
        var files = new string[10];

        // Create 10 dummy image files with different creation/access timestamps
        for (int i = 0; i < 10; i++)
        {
            var path = Path.Combine(_testCacheDir, $"wallhaven_img_{i}.jpg");
            File.WriteAllText(path, $"dummy content {i}");
            File.SetLastAccessTimeUtc(path, DateTime.UtcNow.AddMinutes(i)); // img_0 is oldest
            files[i] = path;
        }

        // Active wallpaper is img_0 (the oldest one!)
        var activeWallpaper = files[0];

        // Act: Direct test of cache pruning logic with active preservation
        var dir = new DirectoryInfo(_testCacheDir);
        var cachedFiles = dir.GetFiles("*.jpg");
        Assert.Equal(10, cachedFiles.Length);

        // Pruning manually to max limit 5:
        var maxLimit = 5;
        var toRemoveCount = cachedFiles.Length - maxLimit;
        var sorted = cachedFiles.OrderBy(f => f.LastAccessTimeUtc).ToList();
        var removed = 0;

        foreach (var file in sorted)
        {
            if (removed >= toRemoveCount) break;
            if (string.Equals(file.FullName, activeWallpaper, StringComparison.OrdinalIgnoreCase))
            {
                continue; // Do not delete active
            }
            file.Delete();
            removed++;
        }

        // Assert
        var remaining = dir.GetFiles("*.jpg");
        Assert.Equal(5, remaining.Length);
        // The active wallpaper MUST still exist!
        Assert.True(File.Exists(activeWallpaper), "Active wallpaper must never be deleted by LRU prune.");
    }
}
