using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using AnimeWallpaper.Models;

namespace AnimeWallpaper.Services;

public class WallpaperRotatorEngine
{
    private readonly IConfigService _configService;
    private readonly IWallhavenService _wallhavenService;
    private readonly IWallpaperService _wallpaperService;
    private readonly IStartupService _startupService;

    private readonly System.Timers.Timer _secondTimer;
    private readonly SemaphoreSlim _rotationLock = new(1, 1);

    private int _secondsRemaining;
    private bool _isRotating;
    private string _status = "Initializing";

    public event Action<string>? StatusChanged;
    public event Action<TimeSpan>? CountdownTicked;
    public event Action<WallhavenItem, string>? WallpaperChanged;
    public event Action<string>? ErrorOccurred;

    public string CurrentStatus => _status;
    public bool IsRotating => _isRotating;
    public bool IsPaused => _configService.State.IsPaused;
    public TimeSpan TimeRemaining => TimeSpan.FromSeconds(Math.Max(0, _secondsRemaining));

    public WallpaperRotatorEngine(
        IConfigService configService,
        IWallhavenService wallhavenService,
        IWallpaperService wallpaperService,
        IStartupService startupService)
    {
        _configService = configService;
        _wallhavenService = wallhavenService;
        _wallpaperService = wallpaperService;
        _startupService = startupService;

        _secondTimer = new System.Timers.Timer(1000);
        _secondTimer.Elapsed += (s, e) => OnSecondTick();
        _secondTimer.AutoReset = true;
    }

    public void Initialize()
    {
        // Sync auto-start with config
        if (_configService.Config.StartWithWindows != _startupService.IsAutoStartEnabled())
        {
            _startupService.SetAutoStart(_configService.Config.StartWithWindows);
        }

        ResetCountdown();

        if (_configService.State.IsPaused)
        {
            SetStatus("Paused");
            _secondTimer.Stop();
        }
        else
        {
            SetStatus("Running");
            _secondTimer.Start();
        }

        // If no active wallpaper yet, rotate immediately in background
        if (string.IsNullOrEmpty(_configService.State.CurrentWallpaperPath) ||
            !File.Exists(_configService.State.CurrentWallpaperPath))
        {
            Logger.Info("No active wallpaper detected. Initiating first wallpaper fetch...");
            _ = Task.Run(() => TriggerRotationAsync(false));
        }
        else
        {
            Logger.Info($"Existing wallpaper active: {_configService.State.CurrentWallpaperId} ({_configService.State.CurrentWallpaperPath})");
        }
    }

    public void Pause()
    {
        _configService.State.IsPaused = true;
        _configService.SaveState();
        _secondTimer.Stop();
        SetStatus("Paused");
        Logger.Info("Wallpaper rotator paused.");
    }

    public void Resume()
    {
        _configService.State.IsPaused = false;
        _configService.SaveState();
        ResetCountdown();
        _secondTimer.Start();
        SetStatus("Running");
        Logger.Info("Wallpaper rotator resumed.");
    }

    public void TogglePause()
    {
        if (IsPaused)
            Resume();
        else
            Pause();
    }

    public async Task<bool> NextWallpaperAsync()
    {
        return await TriggerRotationAsync(true);
    }

    public void UpdateInterval(int minutes)
    {
        _configService.Config.IntervalMinutes = Math.Max(1, minutes);
        _configService.SaveConfig();
        ResetCountdown();
        Logger.Info($"Interval updated to {minutes} minutes.");
    }

    private void ResetCountdown()
    {
        var intervalMinutes = Math.Max(1, _configService.Config.IntervalMinutes);
        _secondsRemaining = intervalMinutes * 60;
        CountdownTicked?.Invoke(TimeRemaining);
    }

    private void OnSecondTick()
    {
        if (_configService.State.IsPaused) return;

        if (_secondsRemaining > 0)
        {
            _secondsRemaining--;
            CountdownTicked?.Invoke(TimeRemaining);
        }

        if (_secondsRemaining <= 0)
        {
            ResetCountdown();
            _ = Task.Run(() => TriggerRotationAsync(false));
        }
    }

    private async Task<bool> TriggerRotationAsync(bool manualTrigger)
    {
        if (!await _rotationLock.WaitAsync(0))
        {
            Logger.Info("Rotation already in progress. Skipping.");
            return false;
        }

        _isRotating = true;
        try
        {
            SetStatus("Searching Wallhaven...");
            var items = await _wallhavenService.SearchWallpapersAsync(_configService.Config);

            if (items == null || items.Count == 0)
            {
                SetStatus("Connection failed");
                ErrorOccurred?.Invoke("Failed to fetch wallpapers from Wallhaven. Retrying next cycle.");
                return false;
            }

            // Filter out recently used wallpapers
            var usedSet = new HashSet<string>(_configService.State.UsedWallpaperIds);
            var candidates = items.Where(i => !usedSet.Contains(i.Id)).ToList();

            // If all candidates in current page were used, fallback to any item not matching current
            if (candidates.Count == 0)
            {
                Logger.Info("All returned items have been used previously. Reusing items...");
                candidates = items.Where(i => i.Id != _configService.State.CurrentWallpaperId).ToList();
                if (candidates.Count == 0)
                {
                    candidates = items;
                }
            }

            // Select item
            WallhavenItem selectedItem;
            if (_configService.Config.Random)
            {
                var rand = new Random();
                selectedItem = candidates[rand.Next(candidates.Count)];
            }
            else
            {
                selectedItem = candidates[0];
            }

            Logger.Info($"Selected wallpaper: {selectedItem.Id} ({selectedItem.Resolution})");

            SetStatus("Downloading...");
            var downloadedPath = await _wallpaperService.DownloadWallpaperAsync(selectedItem.Id, selectedItem.Path);

            if (string.IsNullOrEmpty(downloadedPath) || !File.Exists(downloadedPath))
            {
                SetStatus("Download failed");
                ErrorOccurred?.Invoke($"Failed to download wallpaper {selectedItem.Id}. Retrying next cycle.");
                return false;
            }

            SetStatus("Applying wallpaper...");
            bool applied = _wallpaperService.SetDesktopWallpaper(downloadedPath);

            if (!applied)
            {
                SetStatus("Apply failed");
                ErrorOccurred?.Invoke("Failed to set desktop wallpaper via Windows API.");
                return false;
            }

            // Prune old cached wallpapers (preserves current)
            _wallpaperService.PruneCache(_configService.Config.MaxCachedWallpapers, downloadedPath);

            // Update state
            _configService.State.AddUsedId(selectedItem.Id);
            _configService.State.CurrentWallpaperId = selectedItem.Id;
            _configService.State.CurrentWallpaperPath = downloadedPath;
            _configService.State.CurrentResolution = selectedItem.Resolution;
            _configService.State.LastChanged = DateTime.Now;
            _configService.SaveState();

            // Reset interval countdown
            ResetCountdown();

            SetStatus(_configService.State.IsPaused ? "Paused" : "Running");
            WallpaperChanged?.Invoke(selectedItem, downloadedPath);
            Logger.Info($"Wallpaper successfully rotated to {selectedItem.Id}");

            return true;
        }
        catch (Exception ex)
        {
            Logger.Error("Exception during wallpaper rotation cycle", ex);
            SetStatus("Error");
            ErrorOccurred?.Invoke(ex.Message);
            return false;
        }
        finally
        {
            _isRotating = false;
            _rotationLock.Release();
        }
    }

    private void SetStatus(string status)
    {
        _status = status;
        StatusChanged?.Invoke(status);
    }
}
