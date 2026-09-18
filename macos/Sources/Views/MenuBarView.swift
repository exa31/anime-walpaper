import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var vm: WallpaperViewModel
    @State private var showingSettings: Bool = false
    @State private var customQuery: String = ""

    public var body: some View {
        ZStack {
            if showingSettings {
                SettingsView(vm: vm, onBack: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSettings = false
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                mainContentView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .frame(width: 320)
        .onAppear {
            customQuery = vm.config.query
        }
    }

    private var mainContentView: some View {
        VStack(spacing: 12) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("🌸")
                        .font(.title3)
                    Text("Anime Wallpaper")
                        .font(.headline)
                        .fontWeight(.bold)
                }

                Spacer()

                // Next Rotation badge
                HStack(spacing: 4) {
                    Image(systemName: vm.state.isPaused ? "pause.fill" : "clock.fill")
                        .font(.caption2)
                    Text(vm.nextRotationText)
                        .font(.caption)
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(vm.state.isPaused ? Color.orange.opacity(0.15) : Color.pink.opacity(0.15))
                .foregroundColor(vm.state.isPaused ? .orange : .pink)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            // Current Wallpaper Preview
            ZStack(alignment: .bottomLeading) {
                if !vm.state.currentWallpaperPath.isEmpty,
                   let nsImage = NSImage(contentsOfFile: vm.state.currentWallpaperPath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .id(vm.state.currentWallpaperPath)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 150)
                        .overlay(
                            VStack(spacing: 6) {
                                if vm.isLoading {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Fetching wallpaper...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text("No wallpaper loaded")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        )
                }

                // Overlay gradient & info badge
                if !vm.state.currentWallpaperId.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("#\(vm.state.currentWallpaperId)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            if !vm.state.currentResolution.isEmpty {
                                Text(vm.state.currentResolution)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            Spacer()

                            Button(action: { vm.revealCurrentInFinder() }) {
                                Image(systemName: "folder")
                                    .font(.caption)
                                    .padding(5)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")

                            Button(action: { vm.openWallhavenPage() }) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                                    .padding(5)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("View on Wallhaven")
                        }
                    }
                    .padding(8)
                }
            }
            .padding(.horizontal, 14)

            // Status message
            HStack {
                Circle()
                    .fill(vm.isLoading ? Color.blue : (vm.state.isPaused ? Color.orange : Color.green))
                    .frame(width: 7, height: 7)
                Text(vm.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Primary Control Buttons
            HStack(spacing: 10) {
                Button(action: { vm.nextWallpaper() }) {
                    HStack(spacing: 6) {
                        if vm.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Next Wallpaper")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(vm.isLoading)

                Button(action: { vm.togglePause() }) {
                    HStack(spacing: 4) {
                        Image(systemName: vm.state.isPaused ? "play.fill" : "pause.fill")
                        Text(vm.state.isPaused ? "Resume" : "Pause")
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 14)

            Divider()
                .padding(.horizontal, 14)

            // Search query field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)

                TextField("Search tags (e.g. anime girl, ghibli)", text: $customQuery)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onSubmit {
                        if !customQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            vm.selectPresetQuery(customQuery)
                        }
                    }

                if !customQuery.isEmpty {
                    Button(action: { customQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(7)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 14)

            // Preset Query Chips
            VStack(alignment: .leading, spacing: 6) {
                Text("Popular Presets")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(WallpaperViewModel.presetQueries, id: \.self) { preset in
                            let isSelected = vm.config.query.lowercased() == preset.lowercased()
                            Button(action: {
                                customQuery = preset
                                vm.selectPresetQuery(preset)
                            }) {
                                Text(preset)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isSelected ? Color.pink.opacity(0.2) : Color.secondary.opacity(0.12))
                                    .foregroundColor(isSelected ? .pink : .primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.pink.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }

            Divider()
                .padding(.horizontal, 14)

            // Footer Toolbar
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSettings = true
                    }
                }) {
                    Label("Settings", systemImage: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: { vm.openCacheFolder() }) {
                    Label("\(vm.cachedCount)", systemImage: "photo.stack")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Open Cached Wallpapers Folder (\(vm.cachedCount) cached)")

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Quit", systemImage: "power")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}
