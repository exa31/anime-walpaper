using System.ComponentModel;
using System.Windows;
using System.Windows.Input;
using AnimeWallpaper.ViewModels;

namespace AnimeWallpaper;

public partial class MainWindow : Window
{
    public MainViewModel ViewModel { get; }

    public MainWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        ViewModel = viewModel;
        DataContext = viewModel;
    }

    private void TitleBar_MouseDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ChangedButton == MouseButton.Left)
        {
            DragMove();
        }
    }

    private void MinimizeBtn_Click(object sender, RoutedEventArgs e)
    {
        Hide();
    }

    private void CloseBtn_Click(object sender, RoutedEventArgs e)
    {
        // Minimize to system tray instead of closing app
        Hide();
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        // If app is not explicitly shutting down, cancel close and hide to tray
        if (!App.IsExiting)
        {
            e.Cancel = true;
            Hide();
        }
        else
        {
            base.OnClosing(e);
        }
    }
}
