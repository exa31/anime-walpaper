using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace AnimeWallpaper.Models;

public class WallhavenResponse
{
    [JsonPropertyName("data")]
    public List<WallhavenItem> Data { get; set; } = new();

    [JsonPropertyName("meta")]
    public WallhavenMeta? Meta { get; set; }
}

public class WallhavenItem
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    [JsonPropertyName("short_url")]
    public string ShortUrl { get; set; } = string.Empty;

    [JsonPropertyName("views")]
    public int Views { get; set; }

    [JsonPropertyName("favorites")]
    public int Favorites { get; set; }

    [JsonPropertyName("source")]
    public string Source { get; set; } = string.Empty;

    [JsonPropertyName("purity")]
    public string Purity { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("dimension_x")]
    public int DimensionX { get; set; }

    [JsonPropertyName("dimension_y")]
    public int DimensionY { get; set; }

    [JsonPropertyName("resolution")]
    public string Resolution { get; set; } = string.Empty;

    [JsonPropertyName("ratio")]
    public string Ratio { get; set; } = string.Empty;

    [JsonPropertyName("file_size")]
    public long FileSize { get; set; }

    [JsonPropertyName("file_type")]
    public string FileType { get; set; } = string.Empty;

    [JsonPropertyName("created_at")]
    public string CreatedAt { get; set; } = string.Empty;

    [JsonPropertyName("colors")]
    public List<string> Colors { get; set; } = new();

    [JsonPropertyName("path")]
    public string Path { get; set; } = string.Empty;

    [JsonPropertyName("thumbs")]
    public WallhavenThumbs? Thumbs { get; set; }
}

public class WallhavenThumbs
{
    [JsonPropertyName("large")]
    public string Large { get; set; } = string.Empty;

    [JsonPropertyName("original")]
    public string Original { get; set; } = string.Empty;

    [JsonPropertyName("small")]
    public string Small { get; set; } = string.Empty;
}

public class WallhavenMeta
{
    [JsonPropertyName("current_page")]
    public int CurrentPage { get; set; }

    [JsonPropertyName("last_page")]
    public int LastPage { get; set; }

    [JsonPropertyName("per_page")]
    public int PerPage { get; set; }

    [JsonPropertyName("total")]
    public int Total { get; set; }
}
