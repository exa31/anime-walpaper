using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media.Imaging;
using AnimeWallpaper.Models;
using AnimeWallpaper.Services;
using Application = System.Windows.Application;

namespace AnimeWallpaper.ViewModels;

public class IntervalOption
{
    public string DisplayName { get; set; } = string.Empty;
    public int Minutes { get; set; }

    public override string ToString() => DisplayName;
}

public class MainViewModel : ViewModelBase
{
    private readonly IConfigService _configService;
    private readonly WallpaperRotatorEngine _engine;
    private readonly IWallpaperService _wallpaperService;
    private readonly IStartupService _startupService;

    private BitmapImage? _previewImage;
    private string _wallpaperId = "-";
    private string _resolution = "-";
    private string _lastChangedText = "-";
    private string _fileSizeText = "-";
    private string _statusText = "Initializing";
    private string _statusColor = "#10B981"; // Emerald green
    private string _countdownText = "--:--";
    private string _pauseButtonText = "Pause";
    private int _cachedCount;
    private string _userNotification = string.Empty;

    // Config fields
    private string _query = "anime";
    private IntervalOption _selectedInterval = null!;
    private int _minimumWidth = 1920;
    private int _minimumHeight = 1080;
    private bool _random = true;
    private bool _sfwOnly = true;
    private bool _startWithWindows = true;
    private int _maxCachedWallpapers = 20;
    private string _wallhavenApiKey = string.Empty;
    private bool _showNotifications = true;

    public ObservableCollection<IntervalOption> IntervalOptions { get; } = new()
    {
        new IntervalOption { DisplayName = "5 minutes", Minutes = 5 },
        new IntervalOption { DisplayName = "15 minutes", Minutes = 15 },
        new IntervalOption { DisplayName = "30 minutes", Minutes = 30 },
        new IntervalOption { DisplayName = "1 hour", Minutes = 60 },
        new IntervalOption { DisplayName = "2 hours", Minutes = 120 },
        new IntervalOption { DisplayName = "6 hours", Minutes = 360 },
        new IntervalOption { DisplayName = "12 hours", Minutes = 720 },
    };

    public ObservableCollection<string> PresetQueries { get; } = new()
    {
        "anime",
        "anime girl",
        "cyberpunk anime",
        "landscape anime",
        "studio ghibli",
        "nature anime",
        "makoto shinkai"
    };

    #region Properties

    public BitmapImage? PreviewImage
    {
        get => _previewImage;
        set => SetField(ref _previewImage, value);
    }

    public string WallpaperId
    {
        get => _wallpaperId;
        set => SetField(ref _wallpaperId, value);
    }

    public string Resolution
    {
        get => _resolution;
        set => SetField(ref _resolution, value);
    }

    public string LastChangedText
    {
        get => _lastChangedText;
        set => SetField(ref _lastChangedText, value);
    }

    public string FileSizeText
    {
        get => _fileSizeText;
        set => SetField(ref _fileSizeText, value);
    }

    public string StatusText
    {
        get => _statusText;
        set => SetField(ref _statusText, value);
    }

    public string StatusColor
    {
        get => _statusColor;
        set => SetField(ref _statusColor, value);
    }

    public string CountdownText
    {
        get => _countdownText;
        set => SetField(ref _countdownText, value);
    }

    public string PauseButtonText
    {
        get => _pauseButtonText;
        set => SetField(ref _pauseButtonText, value);
    }

    public int CachedCount
    {
        get => _cachedCount;
        set => SetField(ref _cachedCount, value);
    }

    public string UserNotification
    {
        get => _userNotification;
        set => SetField(ref _userNotification, value);
    }

    public string Query
    {
        get => _query;
        set => SetField(ref _query, value);
    }

    public IntervalOption SelectedInterval
    {
        get => _selectedInterval;
        set
        {
            if (SetField(ref _selectedInterval, value))
            {
                if (value != null)
                {
                    _engine.UpdateInterval(value.Minutes);
                }
            }
        }
    }

    public int MinimumWidth
    {
        get => _minimumWidth;
        set => SetField(ref _minimumWidth, value);
    }

    public int MinimumHeight
    {
        get => _minimumHeight;
        set => SetField(ref _minimumHeight, value);
    }

    public bool Random
    {
        get => _random;
        set => SetField(ref _random, value);
    }

    public bool SfwOnly
    {
        get => _sfwOnly;
        set => SetField(ref _sfwOnly, value);
    }

    public bool StartWithWindows
    {
        get => _startWithWindows;
        set
        {
            if (SetField(ref _startWithWindows, value))
            {
                _startupService.SetAutoStart(value);
            }
        }
    }

    public int MaxCachedWallpapers
    {
        get => _maxCachedWallpapers;
        set => SetField(ref _maxCachedWallpapers, value);
    }

    public string WallhavenApiKey
    {
        get => _wallhavenApiKey;
        set => SetField(ref _wallhavenApiKey, value);
    }

    public bool ShowNotifications
    {
        get => _showNotifications;
        set
        {
            if (SetField(ref _showNotifications, value))
            {
                _configService.Config.ShowNotifications = value;
                _configService.SaveConfig();
            }
        }
    }

    #endregion

    #region Commands

    public ICommand NextWallpaperCommand { get; }
    public ICommand TogglePauseCommand { get; }
    public ICommand SaveSettingsCommand { get; }
    public ICommand OpenCacheFolderCommand { get; }
    public ICommand ClearCacheCommand { get; }
    public ICommand OpenLogsCommand { get; }
    public ICommand OpenInBrowserCommand { get; }
    public ICommand SetPresetQueryCommand { get; }

    #endregion

    public MainViewModel(
        IConfigService configService,
        WallpaperRotatorEngine engine,
        IWallpaperService wallpaperService,
        IStartupService startupService)
    {
        _configService = configService;
        _engine = engine;
        _wallpaperService = wallpaperService;
        _startupService = startupService;

        // Initialize Commands
        NextWallpaperCommand = new RelayCommand(async () => await ExecuteNextWallpaperAsync());
        TogglePauseCommand = new RelayCommand(ExecuteTogglePause);
        SaveSettingsCommand = new RelayCommand(ExecuteSaveSettings);
        OpenCacheFolderCommand = new RelayCommand(() => _wallpaperService.OpenCacheFolder());
        ClearCacheCommand = new RelayCommand(ExecuteClearCache);
        OpenLogsCommand = new RelayCommand(() => Logger.OpenLogFolder());
        OpenInBrowserCommand = new RelayCommand(ExecuteOpenInBrowser);
        SetPresetQueryCommand = new RelayCommand(param =>
        {
            if (param is string preset)
            {
                Query = preset;
                ExecuteSaveSettings();
            }
        });

        // Load values from config
        LoadFromConfig();

        // Subscribe to engine events
        _engine.StatusChanged += OnEngineStatusChanged;
        _engine.CountdownTicked += OnEngineCountdownTicked;
        _engine.WallpaperChanged += OnEngineWallpaperChanged;
        _engine.ErrorOccurred += OnEngineErrorOccurred;

        // Load initial state preview if exists
        LoadInitialState();
        UpdateCacheCount();
    }

    private void LoadFromConfig()
    {
        var cfg = _configService.Config;
        _query = cfg.Query;
        _minimumWidth = cfg.MinimumWidth;
        _minimumHeight = cfg.MinimumHeight;
        _random = cfg.Random;
        _sfwOnly = cfg.SfwOnly;
        _startWithWindows = cfg.StartWithWindows;
        _maxCachedWallpapers = cfg.MaxCachedWallpapers;
        _wallhavenApiKey = cfg.WallhavenApiKey;
        _showNotifications = cfg.ShowNotifications;

        _selectedInterval = IntervalOptions.FirstOrDefault(o => o.Minutes == cfg.IntervalMinutes)
                            ?? IntervalOptions[2]; // Default 30 min

        _pauseButtonText = _configService.State.IsPaused ? "Resume" : "Pause";
    }

    private void LoadInitialState()
    {
        var st = _configService.State;
        if (!string.IsNullOrEmpty(st.CurrentWallpaperPath) && File.Exists(st.CurrentWallpaperPath))
        {
            LoadImageSafe(st.CurrentWallpaperPath);
            WallpaperId = string.IsNullOrEmpty(st.CurrentWallpaperId) ? "-" : st.CurrentWallpaperId;
            Resolution = string.IsNullOrEmpty(st.CurrentResolution) ? "-" : st.CurrentResolution;
            LastChangedText = st.LastChanged.HasValue ? st.LastChanged.Value.ToString("HH:mm") : "-";

            try
            {
                var fi = new FileInfo(st.CurrentWallpaperPath);
                FileSizeText = $"{fi.Length / (1024.0 * 1024.0):F2} MB";
            }
            catch
            {
                FileSizeText = "-";
            }
        }
    }

    private async Task ExecuteNextWallpaperAsync()
    {
        UserNotification = "Fetching new wallpaper...";
        await _engine.NextWallpaperAsync();
    }

    private void ExecuteTogglePause()
    {
        _engine.TogglePause();
        PauseButtonText = _engine.IsPaused ? "Resume" : "Pause";
        UpdateStatusBadge(_engine.CurrentStatus);
    }

    public void ExecuteSaveSettings()
    {
        var cfg = _configService.Config;
        cfg.Query = Query;
        cfg.IntervalMinutes = SelectedInterval?.Minutes ?? 30;
        cfg.MinimumWidth = MinimumWidth;
        cfg.MinimumHeight = MinimumHeight;
        cfg.Random = Random;
        cfg.SfwOnly = SfwOnly;
        cfg.StartWithWindows = StartWithWindows;
        cfg.MaxCachedWallpapers = MaxCachedWallpapers;
        cfg.WallhavenApiKey = WallhavenApiKey;
        cfg.ShowNotifications = ShowNotifications;

        _configService.SaveConfig();
        UserNotification = "Settings saved successfully!";
        Task.Delay(3000).ContinueWith(_ =>
        {
            Application.Current?.Dispatcher.Invoke(() =>
            {
                if (UserNotification == "Settings saved successfully!")
                {
                    UserNotification = string.Empty;
                }
            });
        });
    }

    private void ExecuteClearCache()
    {
        _wallpaperService.ClearCache(_configService.State.CurrentWallpaperPath);
        UpdateCacheCount();
        UserNotification = "Cache cleared (active wallpaper preserved).";
    }

    private void ExecuteOpenInBrowser()
    {
        if (string.IsNullOrEmpty(WallpaperId) || WallpaperId == "-") return;
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = $"https://wallhaven.cc/w/{WallpaperId}",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to open wallpaper in browser", ex);
        }
    }

    private void OnEngineStatusChanged(string status)
    {
        Application.Current?.Dispatcher.Invoke(() =>
        {
            UpdateStatusBadge(status);
        });
    }

    private void UpdateStatusBadge(string status)
    {
        StatusText = status;
        if (status.Contains("Running", StringComparison.OrdinalIgnoreCase))
        {
            StatusColor = "#10B981"; // Emerald
        }
        else if (status.Contains("Downloading", StringComparison.OrdinalIgnoreCase) ||
                 status.Contains("Applying", StringComparison.OrdinalIgnoreCase) ||
                 status.Contains("Searching", StringComparison.OrdinalIgnoreCase))
        {
            StatusColor = "#F59E0B"; // Amber
        }
        else if (status.Contains("Paused", StringComparison.OrdinalIgnoreCase))
        {
            StatusColor = "#9CA3AF"; // Gray
        }
        else
        {
            StatusColor = "#EF4444"; // Red / Error
        }
    }

    private void OnEngineCountdownTicked(TimeSpan remaining)
    {
        Application.Current?.Dispatcher.Invoke(() =>
        {
            CountdownText = $"{(int)remaining.TotalMinutes:D2}:{remaining.Seconds:D2}";
        });
    }

    private void OnEngineWallpaperChanged(WallhavenItem item, string filePath)
    {
        Application.Current?.Dispatcher.Invoke(() =>
        {
            LoadImageSafe(filePath);
            WallpaperId = item.Id;
            Resolution = item.Resolution;
            LastChangedText = DateTime.Now.ToString("HH:mm");

            try
            {
                var fi = new FileInfo(filePath);
                FileSizeText = $"{fi.Length / (1024.0 * 1024.0):F2} MB";
            }
            catch
            {
                FileSizeText = "-";
            }

            UserNotification = $"Changed wallpaper to #{item.Id}";
            UpdateCacheCount();
        });
    }

    private void OnEngineErrorOccurred(string error)
    {
        Application.Current?.Dispatcher.Invoke(() =>
        {
            UserNotification = error;
        });
    }

    private void UpdateCacheCount()
    {
        CachedCount = _wallpaperService.GetCachedCount();
    }

    private void LoadImageSafe(string filePath)
    {
        try
        {
            if (!File.Exists(filePath)) return;

            var bitmap = new BitmapImage();
            bitmap.BeginInit();
            bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.UriSource = new Uri(filePath, UriKind.Absolute);
            bitmap.EndInit();
            bitmap.Freeze(); // Avoid thread-affinity locks

            PreviewImage = bitmap;
        }
        catch (Exception ex)
        {
            Logger.Error($"Could not load preview image: {filePath}", ex);
        }
    }
}
