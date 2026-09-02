using System;
using System.Diagnostics;
using System.IO;

namespace AnimeWallpaper.Services;

public static class Logger
{
    private static readonly object _lock = new();
    private static string? _configuredApiKey;

    public static string LogDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "AnimeWallpaper",
        "logs"
    );

    public static void SetApiKeyToMask(string? apiKey)
    {
        _configuredApiKey = apiKey;
    }

    public static void Info(string message) => Log("INFO", message);
    public static void Warn(string message) => Log("WARN", message);
    public static void Error(string message, Exception? ex = null)
    {
        var fullMessage = ex == null ? message : $"{message} | Exception: {ex.Message}\n{ex.StackTrace}";
        Log("ERROR", fullMessage);
    }

    private static void Log(string level, string message)
    {
        try
        {
            if (!string.IsNullOrEmpty(_configuredApiKey) && _configuredApiKey.Length >= 4)
            {
                message = message.Replace(_configuredApiKey, "***API_KEY_HIDDEN***");
            }

            var line = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} [{level}] {message}";
            Debug.WriteLine(line);

            lock (_lock)
            {
                if (!Directory.Exists(LogDirectory))
                {
                    Directory.CreateDirectory(LogDirectory);
                }

                var logFilePath = Path.Combine(LogDirectory, $"app-{DateTime.Now:yyyyMMdd}.log");
                File.AppendAllText(logFilePath, line + Environment.NewLine);
            }
        }
        catch
        {
            // Logging should never throw and crash the application
        }
    }

    public static void OpenLogFolder()
    {
        try
        {
            if (!Directory.Exists(LogDirectory))
            {
                Directory.CreateDirectory(LogDirectory);
            }
            Process.Start(new ProcessStartInfo
            {
                FileName = LogDirectory,
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Error("Failed to open log directory", ex);
        }
    }
}
