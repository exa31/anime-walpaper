using System;
using System.Diagnostics;
using System.IO;

namespace AnimeWallpaper.Linux.Services;

public class SystemdService
{
    private static string ServiceDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".config", "systemd", "user"
    );

    private static string ServiceFilePath => Path.Combine(ServiceDirectory, "anime-wallpaper.service");

    public static bool InstallService(string executablePath)
    {
        try
        {
            if (!Directory.Exists(ServiceDirectory))
            {
                Directory.CreateDirectory(ServiceDirectory);
            }

            var serviceContent = $"""
[Unit]
Description=Anime Wallpaper Rotator Daemon
After=graphical-session.target network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart={Path.GetFullPath(executablePath)} --daemon
Restart=on-failure
RestartSec=15
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
""";

            File.WriteAllText(ServiceFilePath, serviceContent);
            Logger.Success($"Systemd service file written to: {ServiceFilePath}");

            RunProcess("systemctl", "--user daemon-reload");
            RunProcess("systemctl", "--user enable anime-wallpaper.service");
            RunProcess("systemctl", "--user restart anime-wallpaper.service");

            Logger.Success("Systemd user service enabled and started successfully!");
            Logger.Info("Check status with: systemctl --user status anime-wallpaper.service");
            return true;
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to install systemd service", ex);
            return false;
        }
    }

    public static bool UninstallService()
    {
        try
        {
            RunProcess("systemctl", "--user stop anime-wallpaper.service");
            RunProcess("systemctl", "--user disable anime-wallpaper.service");

            if (File.Exists(ServiceFilePath))
            {
                File.Delete(ServiceFilePath);
            }

            RunProcess("systemctl", "--user daemon-reload");
            Logger.Success("Systemd user service uninstalled successfully.");
            return true;
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to uninstall systemd service", ex);
            return false;
        }
    }

    private static void RunProcess(string program, string arguments)
    {
        try
        {
            using var proc = Process.Start(new ProcessStartInfo
            {
                FileName = program,
                Arguments = arguments,
                UseShellExecute = false,
                CreateNoWindow = true
            });
            proc?.WaitForExit();
        }
        catch { }
    }
}
