using System;
using System.IO;
using System.Text.Json;
using AnimeWallpaper.Models;

namespace AnimeWallpaper.Services;

public interface IConfigService
{
    AppConfig Config { get; }
    AppState State { get; }
    void Load();
    void SaveConfig();
    void SaveState();
    string AppDataDirectory { get; }
}

public class ConfigService : IConfigService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    public string AppDataDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "AnimeWallpaper"
    );

    private string ConfigFilePath => Path.Combine(AppDataDirectory, "config.json");
    private string StateFilePath => Path.Combine(AppDataDirectory, "state.json");

    public AppConfig Config { get; private set; } = new();
    public AppState State { get; private set; } = new();

    public ConfigService()
    {
        Load();
    }

    public void Load()
    {
        try
        {
            if (!Directory.Exists(AppDataDirectory))
            {
                Directory.CreateDirectory(AppDataDirectory);
            }

            // Load or initialize config
            if (File.Exists(ConfigFilePath))
            {
                var json = File.ReadAllText(ConfigFilePath);
                Config = JsonSerializer.Deserialize<AppConfig>(json, JsonOptions) ?? new AppConfig();
                Logger.Info("Loaded configuration from " + ConfigFilePath);
            }
            else
            {
                Config = new AppConfig();
                SaveConfig();
                Logger.Info("Created default configuration at " + ConfigFilePath);
            }

            Logger.SetApiKeyToMask(Config.WallhavenApiKey);

            // Load or initialize state
            if (File.Exists(StateFilePath))
            {
                var stateJson = File.ReadAllText(StateFilePath);
                State = JsonSerializer.Deserialize<AppState>(stateJson, JsonOptions) ?? new AppState();
                Logger.Info($"Loaded state. Previously used IDs: {State.UsedWallpaperIds.Count}");
            }
            else
            {
                State = new AppState();
                SaveState();
                Logger.Info("Created default state at " + StateFilePath);
            }
        }
        catch (Exception ex)
        {
            Logger.Error("Error loading config/state. Falling back to defaults.", ex);
            Config ??= new AppConfig();
            State ??= new AppState();
        }
    }

    public void SaveConfig()
    {
        try
        {
            if (!Directory.Exists(AppDataDirectory))
            {
                Directory.CreateDirectory(AppDataDirectory);
            }

            Logger.SetApiKeyToMask(Config.WallhavenApiKey);
            var json = JsonSerializer.Serialize(Config, JsonOptions);
            File.WriteAllText(ConfigFilePath, json);
            Logger.Info("Configuration saved successfully.");
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to save configuration.", ex);
        }
    }

    public void SaveState()
    {
        try
        {
            if (!Directory.Exists(AppDataDirectory))
            {
                Directory.CreateDirectory(AppDataDirectory);
            }

            var json = JsonSerializer.Serialize(State, JsonOptions);
            File.WriteAllText(StateFilePath, json);
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to save state.", ex);
        }
    }
}
