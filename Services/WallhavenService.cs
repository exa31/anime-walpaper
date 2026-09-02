using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using AnimeWallpaper.Models;

namespace AnimeWallpaper.Services;

public interface IWallhavenService
{
    Task<List<WallhavenItem>> SearchWallpapersAsync(AppConfig config, CancellationToken cancellationToken = default);
}

public class WallhavenService : IWallhavenService
{
    private readonly HttpClient _httpClient;
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public WallhavenService(HttpClient? httpClient = null)
    {
        _httpClient = httpClient ?? new HttpClient();
        _httpClient.Timeout = TimeSpan.FromSeconds(30);
        if (_httpClient.DefaultRequestHeaders.UserAgent.Count == 0)
        {
            _httpClient.DefaultRequestHeaders.UserAgent.Add(
                new ProductInfoHeaderValue("AnimeWallpaperApp", "1.0")
            );
        }
    }

    public async Task<List<WallhavenItem>> SearchWallpapersAsync(AppConfig config, CancellationToken cancellationToken = default)
    {
        try
        {
            var query = string.IsNullOrWhiteSpace(config.Query) ? "anime" : config.Query.Trim();
            var categories = "010"; // 010 = Anime category
            var purity = config.SfwOnly ? "100" : "110"; // 100 = SFW only, 110 = SFW + Sketchy
            var sorting = config.Random ? "random" : "toplist";
            var minWidth = config.MinimumWidth > 0 ? config.MinimumWidth : 1920;
            var minHeight = config.MinimumHeight > 0 ? config.MinimumHeight : 1080;
            var atleast = $"{minWidth}x{minHeight}";

            var uriBuilder = new UriBuilder("https://wallhaven.cc/api/v1/search");
            var queryParams = new List<string>
            {
                $"q={Uri.EscapeDataString(query)}",
                $"categories={categories}",
                $"purity={purity}",
                $"sorting={sorting}",
                $"atleast={atleast}"
            };

            if (!string.IsNullOrWhiteSpace(config.WallhavenApiKey))
            {
                queryParams.Add($"apikey={Uri.EscapeDataString(config.WallhavenApiKey.Trim())}");
            }

            uriBuilder.Query = string.Join("&", queryParams);

            Logger.Info($"Requesting Wallhaven: q='{query}', categories={categories}, purity={purity}, sorting={sorting}, atleast={atleast}");

            using var request = new HttpRequestMessage(HttpMethod.Get, uriBuilder.Uri);

            // Also attach header if API key is provided
            if (!string.IsNullOrWhiteSpace(config.WallhavenApiKey))
            {
                request.Headers.Add("X-API-Key", config.WallhavenApiKey.Trim());
            }

            using var response = await _httpClient.SendAsync(request, cancellationToken);

            if ((int)response.StatusCode == 429)
            {
                Logger.Warn("Wallhaven API rate limit hit (HTTP 429). Will retry on next cycle.");
                return new List<WallhavenItem>();
            }

            if (!response.IsSuccessStatusCode)
            {
                Logger.Warn($"Wallhaven API returned non-success status: {(int)response.StatusCode} {response.ReasonPhrase}");
                return new List<WallhavenItem>();
            }

            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            var result = JsonSerializer.Deserialize<WallhavenResponse>(content, JsonOptions);

            if (result?.Data == null || result.Data.Count == 0)
            {
                Logger.Warn("Wallhaven API returned 0 results for the current query.");
                return new List<WallhavenItem>();
            }

            Logger.Info($"Wallhaven returned {result.Data.Count} wallpapers.");
            return result.Data;
        }
        catch (OperationCanceledException)
        {
            Logger.Info("Wallhaven search request cancelled.");
            return new List<WallhavenItem>();
        }
        catch (HttpRequestException ex)
        {
            Logger.Error("Network error during Wallhaven request. Check internet connection.", ex);
            return new List<WallhavenItem>();
        }
        catch (Exception ex)
        {
            Logger.Error("Unexpected error querying Wallhaven API.", ex);
            return new List<WallhavenItem>();
        }
    }
}
