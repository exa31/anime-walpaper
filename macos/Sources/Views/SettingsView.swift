import SwiftUI

public struct SettingsView: View {
    @ObservedObject var vm: WallpaperViewModel
    var onBack: () -> Void

    let intervals = [
        (5, "5m"),
        (15, "15m"),
        (30, "30m"),
        (60, "1h"),
        (120, "2h"),
        (360, "6h"),
        (720, "12h")
    ]

    let resolutions = [
        (1920, 1080, "1080p"),
        (2560, 1440, "2K QHD"),
        (3840, 2160, "4K UHD")
    ]

    public var body: some View {
        VStack(spacing: 0) {
            // Header with Back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                        Text("Back")
                            .font(.caption)
                    }
                    .foregroundColor(.pink)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(Color.pink.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Preferences")
                    .font(.subheadline)
                    .fontWeight(.bold)

                Spacer()

                // Invisible spacer for centering
                Text("Back")
                    .font(.caption)
                    .opacity(0)
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Rotation Interval
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Rotation Interval", systemImage: "timer")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.pink)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                            ForEach(intervals, id: \.0) { item in
                                let isSelected = vm.config.intervalMinutes == item.0
                                Button(action: {
                                    vm.config.intervalMinutes = item.0
                                    vm.saveConfig()
                                }) {
                                    Text(item.1)
                                        .font(.caption)
                                        .fontWeight(isSelected ? .bold : .regular)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.pink : Color.secondary.opacity(0.12))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Minimum Resolution
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Min Resolution", systemImage: "display")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)

                        HStack(spacing: 6) {
                            ForEach(resolutions, id: \.0) { res in
                                let isSelected = vm.config.minimumWidth == res.0
                                Button(action: {
                                    vm.config.minimumWidth = res.0
                                    vm.config.minimumHeight = res.1
                                    vm.saveConfig()
                                }) {
                                    Text(res.2)
                                        .font(.caption)
                                        .fontWeight(isSelected ? .bold : .regular)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.purple : Color.secondary.opacity(0.12))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Content & System Toggles
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Behaviors", systemImage: "slider.horizontal.3")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        Toggle("Random wallpaper selection", isOn: Binding(
                            get: { vm.config.random },
                            set: { vm.config.random = $0; vm.saveConfig() }
                        ))
                        .font(.caption)

                        Toggle("SFW only (Safe for work)", isOn: Binding(
                            get: { vm.config.sfwOnly },
                            set: { vm.config.sfwOnly = $0; vm.saveConfig() }
                        ))
                        .font(.caption)

                        Toggle("Launch at Login (Auto-start)", isOn: Binding(
                            get: { vm.config.startWithMac },
                            set: { vm.config.startWithMac = $0; vm.saveConfig() }
                        ))
                        .font(.caption)

                        Toggle("Show notification on change", isOn: Binding(
                            get: { vm.config.showNotifications },
                            set: { vm.config.showNotifications = $0; vm.saveConfig() }
                        ))
                        .font(.caption)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Storage & Cache
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Storage & Cache", systemImage: "internaldrive")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.indigo)

                        Stepper(value: Binding(
                            get: { vm.config.maxCachedWallpapers },
                            set: { vm.config.maxCachedWallpapers = $0; vm.saveConfig() }
                        ), in: 5...100, step: 5) {
                            HStack {
                                Text("Max cache limit:")
                                    .font(.caption)
                                Spacer()
                                Text("\(vm.config.maxCachedWallpapers) files")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Cached: \(vm.cachedCount) wallpapers")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("Clear Cache") {
                                vm.clearCache()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        HStack {
                            Button(action: { vm.openCacheFolder() }) {
                                Label("Open Cache", systemImage: "folder")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)

                            Spacer()

                            Button(action: { Logger.openLogFolder() }) {
                                Label("View Logs", systemImage: "doc.text")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Wallhaven API Key
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Wallhaven API Key", systemImage: "key.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)

                        SecureField("Paste API key here...", text: Binding(
                            get: { vm.config.wallhavenApiKey },
                            set: { vm.config.wallhavenApiKey = $0; vm.saveConfig() }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                        Text("Optional. Gives higher rate limits & access to private tags.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 380)
        }
        .frame(width: 320)
    }
}
