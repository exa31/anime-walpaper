using System;
using Microsoft.Win32;

namespace AnimeWallpaper.Services;

public interface IStartupService
{
    bool IsAutoStartEnabled();
    void SetAutoStart(bool enable);
}

public class StartupService : IStartupService
{
    private const string RegistryKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string AppName = "AnimeWallpaper";

    public bool IsAutoStartEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RegistryKeyPath, false);
            if (key == null) return false;

            var val = key.GetValue(AppName) as string;
            return !string.IsNullOrEmpty(val);
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to read auto-start registry key.", ex);
            return false;
        }
    }

    public void SetAutoStart(bool enable)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RegistryKeyPath, true);
            if (key == null) return;

            if (enable)
            {
                var exePath = Environment.ProcessPath;
                if (!string.IsNullOrEmpty(exePath))
                {
                    key.SetValue(AppName, $"\"{exePath}\"");
                    Logger.Info($"Auto-start enabled in HKCU Run: {exePath}");
                }
            }
            else
            {
                if (key.GetValue(AppName) != null)
                {
                    key.DeleteValue(AppName, false);
                    Logger.Info("Auto-start removed from HKCU Run.");
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to update auto-start registry (enable={enable}).", ex);
        }
    }
}
