import SwiftUI
import AppKit

@main
struct AnimeWallpaperApp: App {
    @StateObject private var viewModel = WallpaperViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(vm: viewModel)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
