using System;
using System.IO;
using System.Text.RegularExpressions;

namespace AnimeWallpaper.Linux.Services;

public static class Logger
{
    private static string? _apiKeyToMask;

    private static readonly Regex ApiKeyQueryRegex = new(
        @"(?i)(apikey[=:])\s*([a-zA-Z0-9_\-]+)",
        RegexOptions.Compiled
    );

    private static readonly Regex ApiKeyHeaderRegex = new(
        @"(?i)(x-api-key\s*[:=]\s*)([a-zA-Z0-9_\-]+)",
        RegexOptions.Compiled
    );

    public static void SetApiKeyToMask(string? apiKey)
    {
        _apiKeyToMask = string.IsNullOrWhiteSpace(apiKey) ? null : apiKey.Trim();
    }

    public static string Sanitize(string message)
    {
        if (string.IsNullOrEmpty(message))
        {
            return string.Empty;
        }

        var result = message;

        // Specific configured key replacement
        if (!string.IsNullOrEmpty(_apiKeyToMask) && _apiKeyToMask.Length >= 4)
        {
            result = result.Replace(_apiKeyToMask, "[REDACTED_API_KEY]");
        }

        // Generic apikey= patterns in URLs or query strings
        result = ApiKeyQueryRegex.Replace(result, "$1[REDACTED_API_KEY]");

        // Generic X-API-Key header patterns
        result = ApiKeyHeaderRegex.Replace(result, "$1[REDACTED_API_KEY]");

        return result;
    }

    public static void Info(string message)
    {
        var formatted = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] [INFO] {Sanitize(message)}";
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine(formatted);
        Console.ResetColor();
    }

    public static void Success(string message)
    {
        var formatted = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] [OK]   {Sanitize(message)}";
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine(formatted);
        Console.ResetColor();
    }

    public static void Warn(string message)
    {
        var formatted = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] [WARN] {Sanitize(message)}";
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine(formatted);
        Console.ResetColor();
    }

    public static void Error(string message, Exception? ex = null)
    {
        var formatted = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] [ERROR] {Sanitize(message)}";
        if (ex != null)
        {
            formatted += $" | Details: {Sanitize(ex.Message)}";
        }
        Console.ForegroundColor = ConsoleColor.Red;
        Console.Error.WriteLine(formatted);
        Console.ResetColor();
    }
}
