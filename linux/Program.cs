using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using AnimeWallpaper.Linux.Models;
using AnimeWallpaper.Linux.Services;

namespace AnimeWallpaper.Linux;

public static class Program
{
    private static readonly CancellationTokenSource Cts = new();

    public static async Task<int> Main(string[] args)
    {
        Console.CancelKeyPress += (_, e) =>
        {
            e.Cancel = true;
            Logger.Info("Shutdown signal received. Stopping gracefully...");
            Cts.Cancel();
        };

        var configService = new LinuxConfigService();
        var config = configService.LoadConfig();
        var wallpaperService = new LinuxWallpaperService();
        var wallhavenService = new WallhavenService();

        if (args.Length == 0 || args[0] is "-h" or "--help" or "help")
        {
            PrintHelp();
            return 0;
        }

        for (int i = 0; i < args.Length; i++)
        {
            var arg = args[i].ToLowerInvariant();

            switch (arg)
            {
                case "-n":
                case "--next":
                    return await RotateNextAsync(config, wallhavenService, wallpaperService) ? 0 : 1;

                case "-d":
                case "--daemon":
                    await RunDaemonAsync(config, configService, wallhavenService, wallpaperService, Cts.Token);
                    return 0;

                case "--status":
                    PrintStatus(config, configService, wallpaperService);
                    return 0;

                case "--query" or "-q" when i + 1 < args.Length:
                    config.Query = args[++i];
                    configService.SaveConfig(config);
                    Logger.Success($"Query updated to: '{config.Query}'");
                    return 0;

                case "--interval" or "-i" when i + 1 < args.Length:
                    if (int.TryParse(args[++i], out var mins) && mins > 0)
                    {
                        config.IntervalMinutes = mins;
                        configService.SaveConfig(config);
                        Logger.Success($"Rotation interval updated to: {mins} minutes.");
                    }
                    else
                    {
                        Logger.Error("Invalid interval minutes.");
                        return 1;
                    }
                    return 0;

                case "--apikey" when i + 1 < args.Length:
                    config.WallhavenApiKey = args[++i];
                    configService.SaveConfig(config);
                    Logger.Success("Wallhaven API key saved successfully.");
                    return 0;

                case "--purity" when i + 1 < args.Length:
                    var p = args[++i].ToLowerInvariant();
                    config.SfwOnly = p == "sfw";
                    configService.SaveConfig(config);
                    Logger.Success($"Purity set to: {(config.SfwOnly ? "SFW only" : "SFW + Sketchy")}");
                    return 0;

                case "--clear-cache":
                    wallpaperService.ClearCache(wallpaperService.GetCurrentWallpaper());
                    return 0;

                case "--install-service":
                    var exePath = Environment.ProcessPath ?? Environment.GetCommandLineArgs()[0];
                    return SystemdService.InstallService(exePath) ? 0 : 1;

                case "--uninstall-service":
                    return SystemdService.UninstallService() ? 0 : 1;

                default:
                    Logger.Warn($"Unknown argument: {args[i]}");
                    PrintHelp();
                    return 1;
            }
        }

        return 0;
    }

    private static async Task<bool> RotateNextAsync(AppConfig config, WallhavenService wallhaven, LinuxWallpaperService wallpaperService)
    {
        Logger.Info("Fetching next anime wallpaper from Wallhaven...");
        var items = await wallhaven.SearchWallpapersAsync(config);

        if (items.Count == 0)
        {
            Logger.Warn("No wallpapers found for the current query/filter.");
            return false;
        }

        var random = new Random();
        var selected = items[random.Next(items.Count)];
        Logger.Info($"Selected wallpaper: #{selected.Id} [{selected.Resolution}] ({selected.Path})");

        var downloadedPath = await wallpaperService.DownloadWallpaperAsync(selected.Id, selected.Path);
        if (downloadedPath == null)
        {
            Logger.Error("Failed to download wallpaper.");
            return false;
        }

        var applied = wallpaperService.SetDesktopWallpaper(downloadedPath, config.CustomWallpaperCommand);
        if (applied)
        {
            Logger.Success($"Wallpaper successfully updated: {downloadedPath}");
            wallpaperService.PruneCache(config.MaxCachedWallpapers, downloadedPath);
            return true;
        }

        Logger.Error("Failed to apply desktop wallpaper.");
        return false;
    }

    private static async Task RunDaemonAsync(
        AppConfig config,
        LinuxConfigService configService,
        WallhavenService wallhaven,
        LinuxWallpaperService wallpaperService,
        CancellationToken cancellationToken)
    {
        Logger.Info("==================================================");
        Logger.Info("🌸 Anime Wallpaper Daemon running on Linux");
        Logger.Info($"Interval: {config.IntervalMinutes} minutes | Query: '{config.Query}'");
        Logger.Info("Press Ctrl+C to terminate the daemon.");
        Logger.Info("==================================================");

        // Immediate first rotation
        await RotateNextAsync(config, wallhaven, wallpaperService);

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var delay = TimeSpan.FromMinutes(config.IntervalMinutes);
                Logger.Info($"Next rotation scheduled in {config.IntervalMinutes} minute(s).");
                await Task.Delay(delay, cancellationToken);

                // Reload config in case it was edited externally via CLI
                config = configService.LoadConfig();
                await RotateNextAsync(config, wallhaven, wallpaperService);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                Logger.Error("Error during daemon cycle. Retrying in 60 seconds...", ex);
                try
                {
                    await Task.Delay(TimeSpan.FromSeconds(60), cancellationToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        Logger.Info("Anime Wallpaper Daemon stopped.");
    }

    private static void PrintStatus(AppConfig config, LinuxConfigService configService, LinuxWallpaperService wallpaperService)
    {
        Console.ForegroundColor = ConsoleColor.Magenta;
        Console.WriteLine("\n🌸 Anime Wallpaper Linux Status");
        Console.WriteLine("---------------------------------------------");
        Console.ResetColor();

        Console.WriteLine($"Config File:       {configService.ConfigFilePath}");
        Console.WriteLine($"Cache Folder:      {wallpaperService.CacheDirectory}");
        Console.WriteLine($"Search Query:      '{config.Query}'");
        Console.WriteLine($"Interval:          {config.IntervalMinutes} minutes");
        Console.WriteLine($"Purity Filter:     {(config.SfwOnly ? "SFW Only (100)" : "SFW + Sketchy (110)")}");
        Console.WriteLine($"Min Resolution:    {config.MinimumWidth}x{config.MinimumHeight}");
        Console.WriteLine($"Max Cache Limit:   {config.MaxCachedWallpapers} files");
        Console.WriteLine($"Cached Files:      {wallpaperService.GetCachedCount()} files");

        var current = wallpaperService.GetCurrentWallpaper();
        Console.WriteLine($"Current Wallpaper: {(string.IsNullOrEmpty(current) ? "[None recorded yet]" : current)}");
        Console.WriteLine("---------------------------------------------\n");
    }

    private static void PrintHelp()
    {
        Console.ForegroundColor = ConsoleColor.Magenta;
        Console.WriteLine(@"
    🌸 Anime Wallpaper for Linux (CLI & Daemon)
    Auto-rotator anime wallpaper powered by Wallhaven API
        ");
        Console.ResetColor();

        Console.WriteLine(@"USAGE:
    anime-wallpaper [OPTIONS]

COMMANDS:
    -n, --next              Fetch and apply the next anime wallpaper immediately
    -d, --daemon            Run in background daemon mode with periodic rotation
    --status                Display current configuration and active wallpaper status
    -q, --query <tags>      Update default search query tags (e.g. 'landscape anime')
    -i, --interval <mins>   Update rotation interval in minutes
    --purity <sfw|sketchy>  Set content purity filter
    --apikey <key>          Set Wallhaven API key (stored securely, masked in logs)
    --clear-cache           Delete all cached wallpapers except the active one
    --install-service       Generate and register systemd user service (auto-start)
    --uninstall-service     Unregister and stop systemd user service
    -h, --help              Show this help message

EXAMPLES:
    anime-wallpaper --next
    anime-wallpaper --query 'cyberpunk anime' --next
    anime-wallpaper --daemon
    anime-wallpaper --install-service
");
    }
}
