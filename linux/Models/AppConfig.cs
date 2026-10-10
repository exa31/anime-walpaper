using System.Text.Json.Serialization;

namespace AnimeWallpaper.Linux.Models;

public class AppConfig
{
    [JsonPropertyName("wallhavenApiKey")]
    public string WallhavenApiKey { get; set; } = string.Empty;

    [JsonPropertyName("query")]
    public string Query { get; set; } = "anime";

    [JsonPropertyName("intervalMinutes")]
    public int IntervalMinutes { get; set; } = 30;

    [JsonPropertyName("minimumWidth")]
    public int MinimumWidth { get; set; } = 1920;

    [JsonPropertyName("minimumHeight")]
    public int MinimumHeight { get; set; } = 1080;

    [JsonPropertyName("sfwOnly")]
    public bool SfwOnly { get; set; } = true;

    [JsonPropertyName("random")]
    public bool Random { get; set; } = true;

    [JsonPropertyName("maxCachedWallpapers")]
    public int MaxCachedWallpapers { get; set; } = 20;

    [JsonPropertyName("customWallpaperCommand")]
    public string CustomWallpaperCommand { get; set; } = string.Empty;

    public AppConfig Clone()
    {
        return (AppConfig)MemberwiseClone();
    }
}
