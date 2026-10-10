using AnimeWallpaper.Linux.Services;
using Xunit;

namespace AnimeWallpaper.Tests;

public class SecurityAndSanitizationTests
{
    [Theory]
    [InlineData("my_super_secret_token_999")]
    [InlineData("api_key_walhaven_xyz12345")]
    public void Logger_Sanitize_MasksConfiguredApiKey(string secretKey)
    {
        // Arrange
        Logger.SetApiKeyToMask(secretKey);
        var logMessage = $"Connecting with token: {secretKey} to server.";

        // Act
        var sanitized = Logger.Sanitize(logMessage);

        // Assert
        Assert.DoesNotContain(secretKey, sanitized);
        Assert.Contains("[REDACTED_API_KEY]", sanitized);
    }

    [Fact]
    public void Logger_Sanitize_AutomaticallyMasksUrlQueryAndHeaderApiKeyPatterns()
    {
        // Arrange
        var messageWithUrl = "Request failed: https://wallhaven.cc/api/v1/search?q=anime&apikey=unregisteredSecretKey987";
        var messageWithHeader = "Outgoing request headers: X-API-Key: customSecretToken456";

        // Act
        var sanitizedUrl = Logger.Sanitize(messageWithUrl);
        var sanitizedHeader = Logger.Sanitize(messageWithHeader);

        // Assert
        Assert.DoesNotContain("unregisteredSecretKey987", sanitizedUrl);
        Assert.Contains("apikey=[REDACTED_API_KEY]", sanitizedUrl);

        Assert.DoesNotContain("customSecretToken456", sanitizedHeader);
        Assert.Contains("X-API-Key: [REDACTED_API_KEY]", sanitizedHeader);
    }

    [Theory]
    [InlineData("abc123", true)]
    [InlineData("wallhaven-x9y8z7", true)]
    [InlineData("image_2024_01", true)]
    [InlineData("../etc/passwd", false)]
    [InlineData("../../windows/win.ini", false)]
    [InlineData("abc/def", false)]
    [InlineData("abc\\def", false)]
    [InlineData("abc;rm -rf", false)]
    [InlineData("", false)]
    [InlineData("   ", false)]
    public void IsValidWallpaperId_PreventsPathTraversal(string id, bool expectedValid)
    {
        // Act
        var isValid = LinuxWallpaperService.IsValidWallpaperId(id);

        // Assert
        Assert.Equal(expectedValid, isValid);
    }

    [Theory]
    [InlineData("https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg", true)]
    [InlineData("https://wallhaven.cc/uploads/sample.png", true)]
    [InlineData("http://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg", false)] // Insecure HTTP
    [InlineData("file:///etc/shadow", false)] // File protocol
    [InlineData("https://evil.com/malware.png", false)] // Foreign host
    [InlineData("https://127.0.0.1/secret.png", false)] // Localhost IP
    [InlineData("https://localhost:8080/image.jpg", false)]
    [InlineData("not-a-valid-url", false)]
    public void IsValidWallpaperUrl_EnforcesHttpsAndWhitelistsDomain(string url, bool expectedValid)
    {
        // Act
        var isValid = LinuxWallpaperService.IsValidWallpaperUrl(url);

        // Assert
        Assert.Equal(expectedValid, isValid);
    }

    [Theory]
    [InlineData("swww img {file} --transition-type wipe", true)]
    [InlineData("feh --bg-fill {file}", true)]
    [InlineData("plasma-apply-wallpaperimage {file}", true)]
    [InlineData("swww img {file}; rm -rf /", false)] // Semicolon command chaining
    [InlineData("swww img {file} && curl evil.com", false)] // Logical AND chaining
    [InlineData("swww img {file} || shutdown -h now", false)] // Logical OR chaining
    [InlineData("swww img `whoami`", false)] // Backticks execution
    [InlineData("swww img $(whoami)", false)] // Subshell execution
    [InlineData("swww img {file} > /dev/null", false)] // Redirection
    [InlineData("feh --bg-fill /some/static/image.jpg", false)] // Missing {file} placeholder
    public void IsSafeCustomCommand_PreventsCommandInjection(string command, bool expectedSafe)
    {
        // Act
        var isSafe = LinuxWallpaperService.IsSafeCustomCommand(command);

        // Assert
        Assert.Equal(expectedSafe, isSafe);
    }
}
