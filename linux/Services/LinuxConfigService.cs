using System;
using System.IO;
using System.Text.Json;
using AnimeWallpaper.Linux.Models;

namespace AnimeWallpaper.Linux.Services;

public class LinuxConfigService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    public string ConfigDirectory
    {
        get
        {
            var xdgConfigHome = Environment.GetEnvironmentVariable("XDG_CONFIG_HOME");
            if (!string.IsNullOrWhiteSpace(xdgConfigHome))
            {
                return Path.Combine(xdgConfigHome, "AnimeWallpaper");
            }
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            return Path.Combine(home, ".config", "AnimeWallpaper");
        }
    }

    public string ConfigFilePath => Path.Combine(ConfigDirectory, "config.json");

    public AppConfig LoadConfig()
    {
        try
        {
            if (File.Exists(ConfigFilePath))
            {
                var json = File.ReadAllText(ConfigFilePath);
                var config = JsonSerializer.Deserialize<AppConfig>(json, JsonOptions);
                if (config != null)
                {
                    Logger.SetApiKeyToMask(config.WallhavenApiKey);
                    return config;
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Warn($"Failed to read config file at {ConfigFilePath}. Using defaults. Error: {ex.Message}");
        }

        var defaultConfig = new AppConfig();
        SaveConfig(defaultConfig);
        return defaultConfig;
    }

    public void SaveConfig(AppConfig config)
    {
        try
        {
            if (!Directory.Exists(ConfigDirectory))
            {
                Directory.CreateDirectory(ConfigDirectory);
            }

            var json = JsonSerializer.Serialize(config, JsonOptions);
            File.WriteAllText(ConfigFilePath, json);
            Logger.SetApiKeyToMask(config.WallhavenApiKey);
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to save config file to {ConfigFilePath}", ex);
        }
    }
}
