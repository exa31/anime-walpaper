using System;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows;
using System.Windows.Forms;
using AnimeWallpaper.Services;
using AnimeWallpaper.ViewModels;
using Application = System.Windows.Application;
using MessageBox = System.Windows.MessageBox;

namespace AnimeWallpaper;

public partial class App : Application
{
    private const string MutexName = "Local\\AnimeWallpaper_SingleInstance_Mutex";
    private static Mutex? _mutex;
    public static bool IsExiting { get; private set; }

    private NotifyIcon? _notifyIcon;
    private ToolStripMenuItem? _pauseMenuItem;
    private ToolStripMenuItem? _statusMenuItem;
    private MainWindow? _mainWindow;
    private WallpaperRotatorEngine? _engine;
    private IConfigService? _configService;
    private IWallpaperService? _wallpaperService;
    private MainViewModel? _viewModel;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // 1. Single Instance Check
        _mutex = new Mutex(true, MutexName, out bool createdNew);
        if (!createdNew)
        {
            MessageBox.Show("Anime Wallpaper is already running in the background or system tray.",
                "Anime Wallpaper", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        Logger.Info("=================== Anime Wallpaper Starting ===================");

        // 2. Instantiate Services
        _configService = new ConfigService();
        var wallhavenService = new WallhavenService();
        _wallpaperService = new WallpaperService();
        var startupService = new StartupService();

        _engine = new WallpaperRotatorEngine(
            _configService,
            wallhavenService,
            _wallpaperService,
            startupService
        );

        // 3. ViewModel & MainWindow
        _viewModel = new MainViewModel(_configService, _engine, _wallpaperService, startupService);
        _mainWindow = new MainWindow(_viewModel);

        // 4. Initialize System Tray Icon
        InitializeTrayIcon();

        // 5. Connect Engine Events for Tray / Notifications
        _engine.StatusChanged += OnEngineStatusChanged;
        _engine.WallpaperChanged += OnEngineWallpaperChanged;

        // 6. Start Engine
        _engine.Initialize();

        // 7. Window display logic: show window on normal launch, or hide if launched with --minimized / --silent
        bool startMinimized = false;
        foreach (var arg in e.Args)
        {
            if (arg.Equals("--minimized", StringComparison.OrdinalIgnoreCase) ||
                arg.Equals("--tray", StringComparison.OrdinalIgnoreCase) ||
                arg.Equals("-silent", StringComparison.OrdinalIgnoreCase))
            {
                startMinimized = true;
                break;
            }
        }

        if (!startMinimized)
        {
            _mainWindow.Show();
        }
        else
        {
            _notifyIcon?.ShowBalloonTip(2000, "Anime Wallpaper", "Running in the background. Double-click tray icon to open settings.", ToolTipIcon.Info);
        }
    }

    private void InitializeTrayIcon()
    {
        _notifyIcon = new NotifyIcon();

        // Load Icon
        try
        {
            var resInfo = Application.GetResourceStream(new Uri("pack://application:,,,/Resources/app.ico"));
            if (resInfo != null)
            {
                using var stream = resInfo.Stream;
                _notifyIcon.Icon = new Icon(stream);
            }
            else
            {
                _notifyIcon.Icon = SystemIcons.Application;
            }
        }
        catch (Exception ex)
        {
            Logger.Warn("Could not load embedded tray icon. Using default. " + ex.Message);
            _notifyIcon.Icon = SystemIcons.Application;
        }

        _notifyIcon.Text = "Anime Wallpaper";
        _notifyIcon.Visible = true;

        // Tray Context Menu
        var contextMenu = new ContextMenuStrip();

        // Header (Bold, non-clickable)
        var titleItem = new ToolStripMenuItem("Anime Wallpaper")
        {
            Font = new Font(contextMenu.Font, System.Drawing.FontStyle.Bold),
            Enabled = false
        };
        contextMenu.Items.Add(titleItem);

        // Status Item
        _statusMenuItem = new ToolStripMenuItem("● Status: Running")
        {
            Enabled = false
        };
        contextMenu.Items.Add(_statusMenuItem);

        contextMenu.Items.Add(new ToolStripSeparator());

        // Next Wallpaper
        var nextItem = new ToolStripMenuItem("Next Wallpaper", null, async (s, e) =>
        {
            if (_engine != null)
            {
                await _engine.NextWallpaperAsync();
            }
        });
        contextMenu.Items.Add(nextItem);

        // Pause / Resume
        _pauseMenuItem = new ToolStripMenuItem(_engine?.IsPaused == true ? "Resume" : "Pause", null, (s, e) =>
        {
            if (_engine != null)
            {
                _engine.TogglePause();
                UpdatePauseMenuItemText();
            }
        });
        contextMenu.Items.Add(_pauseMenuItem);

        // Open Settings
        var settingsItem = new ToolStripMenuItem("Open Settings", null, (s, e) =>
        {
            ShowMainWindow();
        });
        contextMenu.Items.Add(settingsItem);

        // Open Cache Folder
        var cacheItem = new ToolStripMenuItem("Open Cache Folder", null, (s, e) =>
        {
            _wallpaperService?.OpenCacheFolder();
        });
        contextMenu.Items.Add(cacheItem);

        contextMenu.Items.Add(new ToolStripSeparator());

        // Exit
        var exitItem = new ToolStripMenuItem("Exit", null, (s, e) =>
        {
            ExitApplication();
        });
        contextMenu.Items.Add(exitItem);

        _notifyIcon.ContextMenuStrip = contextMenu;

        // Double click tray icon opens UI
        _notifyIcon.DoubleClick += (s, e) =>
        {
            ShowMainWindow();
        };
    }

    private void ShowMainWindow()
    {
        if (_mainWindow == null) return;

        if (!_mainWindow.IsVisible)
        {
            _mainWindow.Show();
        }

        if (_mainWindow.WindowState == WindowState.Minimized)
        {
            _mainWindow.WindowState = WindowState.Normal;
        }

        _mainWindow.Activate();
        _mainWindow.Focus();
    }

    private void UpdatePauseMenuItemText()
    {
        if (_pauseMenuItem != null && _engine != null)
        {
            _pauseMenuItem.Text = _engine.IsPaused ? "Resume" : "Pause";
        }
    }

    private void OnEngineStatusChanged(string status)
    {
        if (_statusMenuItem != null)
        {
            _statusMenuItem.Text = $"● Status: {status}";
        }
        UpdatePauseMenuItemText();
    }

    private void OnEngineWallpaperChanged(Models.WallhavenItem item, string filePath)
    {
        if (_configService?.Config.ShowNotifications == true && _notifyIcon != null)
        {
            _notifyIcon.ShowBalloonTip(
                3000,
                "Anime Wallpaper Changed",
                $"Wallpaper #{item.Id} ({item.Resolution}) is now your desktop background!",
                ToolTipIcon.Info
            );
        }
    }

    public void ExitApplication()
    {
        IsExiting = true;
        Logger.Info("Exiting Anime Wallpaper application.");

        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
            _notifyIcon = null;
        }

        _configService?.SaveState();
        _configService?.SaveConfig();

        _mainWindow?.Close();
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }

        _mutex?.ReleaseMutex();
        _mutex?.Dispose();

        base.OnExit(e);
    }
}
