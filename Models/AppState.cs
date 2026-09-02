using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace AnimeWallpaper.Models;

public class AppState
{
    [JsonPropertyName("usedWallpaperIds")]
    public List<string> UsedWallpaperIds { get; set; } = new();

    [JsonPropertyName("currentWallpaperId")]
    public string CurrentWallpaperId { get; set; } = string.Empty;

    [JsonPropertyName("currentWallpaperPath")]
    public string CurrentWallpaperPath { get; set; } = string.Empty;

    [JsonPropertyName("currentResolution")]
    public string CurrentResolution { get; set; } = string.Empty;

    [JsonPropertyName("lastChanged")]
    public DateTime? LastChanged { get; set; }

    [JsonPropertyName("isPaused")]
    public bool IsPaused { get; set; } = false;

    public void AddUsedId(string id, int maxTracked = 200)
    {
        if (string.IsNullOrWhiteSpace(id)) return;

        UsedWallpaperIds.Remove(id);
        UsedWallpaperIds.Add(id);

        if (UsedWallpaperIds.Count > maxTracked)
        {
            UsedWallpaperIds.RemoveRange(0, UsedWallpaperIds.Count - maxTracked);
        }
    }
}
