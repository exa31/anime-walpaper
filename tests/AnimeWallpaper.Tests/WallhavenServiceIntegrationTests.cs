using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using AnimeWallpaper.Linux.Models;
using AnimeWallpaper.Linux.Services;
using Xunit;

namespace AnimeWallpaper.Tests;

public class WallhavenServiceIntegrationTests
{
    private const string SampleValidJsonResponse = """
    {
      "data": [
        {
          "id": "abc123",
          "url": "https://wallhaven.cc/w/abc123",
          "purity": "100",
          "category": "anime",
          "dimension_x": 1920,
          "dimension_y": 1080,
          "resolution": "1920x1080",
          "ratio": "16:9",
          "file_size": 204800,
          "file_type": "image/jpeg",
          "path": "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg"
        },
        {
          "id": "def456",
          "url": "https://wallhaven.cc/w/def456",
          "purity": "010",
          "category": "anime",
          "dimension_x": 2560,
          "dimension_y": 1440,
          "resolution": "2560x1440",
          "ratio": "16:9",
          "file_size": 409600,
          "file_type": "image/png",
          "path": "https://w.wallhaven.cc/full/de/wallhaven-def456.png"
        }
      ],
      "meta": {
        "current_page": 1,
        "last_page": 10,
        "per_page": 2,
        "total": 20
      }
    }
    """;

    [Fact]
    public async Task SearchWallpapers_WithValidResponse_ParsesItemsCorrectly()
    {
        // Arrange
        var mockHandler = MockHttpMessageHandler.WithJsonResponse(SampleValidJsonResponse);
        var httpClient = new HttpClient(mockHandler);
        var service = new WallhavenService(httpClient);
        var config = new AppConfig
        {
            Query = "landscape anime",
            SfwOnly = false // Allow both to verify raw item parsing
        };

        // Act
        var results = await service.SearchWallpapersAsync(config);

        // Assert
        Assert.Equal(2, results.Count);
        Assert.Equal("abc123", results[0].Id);
        Assert.Equal("1920x1080", results[0].Resolution);
        Assert.Equal("def456", results[1].Id);
        Assert.Single(mockHandler.SentRequests);
    }

    [Fact]
    public async Task SearchWallpapers_WithSfwOnly_FiltersOutNonSfwWallpapers()
    {
        // Arrange
        var mockHandler = MockHttpMessageHandler.WithJsonResponse(SampleValidJsonResponse);
        var httpClient = new HttpClient(mockHandler);
        var service = new WallhavenService(httpClient);
        var config = new AppConfig
        {
            Query = "anime",
            SfwOnly = true // Strict SFW
        };

        // Act
        var results = await service.SearchWallpapersAsync(config);

        // Assert
        // Item def456 has purity = "010" (sketchy), so it must be dropped by the strict verifier
        Assert.Single(results);
        Assert.Equal("abc123", results[0].Id);
        Assert.Equal("100", results[0].Purity);
    }

    [Fact]
    public async Task SearchWallpapers_OnHttp429RateLimit_ReturnsEmptyListWithoutCrashing()
    {
        // Arrange
        var mockHandler = MockHttpMessageHandler.WithStatusCode((HttpStatusCode)429);
        var httpClient = new HttpClient(mockHandler);
        var service = new WallhavenService(httpClient);
        var config = new AppConfig { Query = "anime" };

        // Act
        var results = await service.SearchWallpapersAsync(config);

        // Assert
        Assert.NotNull(results);
        Assert.Empty(results);
    }

    [Fact]
    public async Task SearchWallpapers_OnHttp500ServerError_ReturnsEmptyListWithoutCrashing()
    {
        // Arrange
        var mockHandler = MockHttpMessageHandler.WithStatusCode(HttpStatusCode.InternalServerError);
        var httpClient = new HttpClient(mockHandler);
        var service = new WallhavenService(httpClient);
        var config = new AppConfig { Query = "anime" };

        // Act
        var results = await service.SearchWallpapersAsync(config);

        // Assert
        Assert.NotNull(results);
        Assert.Empty(results);
    }

    [Fact]
    public async Task SearchWallpapers_WithApiKey_AttachesHeadersAndQueryParams()
    {
        // Arrange
        var mockHandler = MockHttpMessageHandler.WithJsonResponse(SampleValidJsonResponse);
        var httpClient = new HttpClient(mockHandler);
        var service = new WallhavenService(httpClient);
        var config = new AppConfig
        {
            Query = "anime",
            WallhavenApiKey = "secret_test_token_12345"
        };

        // Act
        await service.SearchWallpapersAsync(config);

        // Assert
        var sent = Assert.Single(mockHandler.SentRequests);
        Assert.Contains("apikey=secret_test_token_12345", sent.RequestUri?.Query);
        Assert.True(sent.Headers.Contains("X-API-Key"));
    }
}
