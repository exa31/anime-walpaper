import SwiftUI

public enum PreviewOverlayMode: String, CaseIterable {
    case clean = "Raw"
    case lockScreen = "Lock Screen"
    case homeScreen = "Home Screen"
}

public struct ContentView: View {
    @State private var query: String = "anime"
    @State private var sfwOnly: Bool = true
    @State private var currentItem: WallhavenItem?
    @State private var isLoading: Bool = false
    @State private var overlayMode: PreviewOverlayMode = .clean
    @State private var showShortcutsGuide: Bool = false
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    private let presetChips = [
        "anime", "anime girl", "cyberpunk anime",
        "landscape anime", "studio ghibli", "makoto shinkai"
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [Color(red: 0.10, green: 0.07, blue: 0.15), Color(red: 0.05, green: 0.03, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Title bar
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("🌸 Anime Wallpaper")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.45, blue: 0.65), Color(red: 0.5, green: 0.85, blue: 1.0)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                Text("Curated Wallhaven Anime Art")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Button {
                                showShortcutsGuide = true
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)

                        // Preset Category Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presetChips, id: \.self) { chip in
                                    Button {
                                        query = chip
                                        fetchNextWallpaper()
                                    } label: {
                                        Text(chip)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(query == chip ? .white : .white.opacity(0.7))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(
                                                query == chip
                                                    ? Color(red: 1.0, green: 0.42, blue: 0.60)
                                                    : Color.white.opacity(0.08)
                                            )
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Preview Mode Selector (Clean vs Lock Screen vs Home Screen)
                        Picker("Preview Mode", selection: $overlayMode) {
                            ForEach(PreviewOverlayMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        // Wallpaper Live Card with Mock Overlays
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 480)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )

                            if let item = currentItem, let url = URL(string: item.thumbs?.large ?? item.path) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView().tint(Color(red: 1.0, green: 0.45, blue: 0.65))
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 480)
                                            .clipped()
                                            .cornerRadius(24)
                                    case .failure:
                                        Text("Failed to load image").foregroundColor(.gray)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }

                                // Interactive Overlays
                                if overlayMode == .lockScreen {
                                    LockScreenMockOverlay()
                                } else if overlayMode == .homeScreen {
                                    HomeScreenMockOverlay()
                                }

                                // Metadata bar at the bottom
                                VStack {
                                    Spacer()
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("#\(item.id) • \(item.resolution ?? "")")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            Text(item.category ?? "Anime")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Material.ultraThinMaterial
                                    )
                                    .cornerRadius(16)
                                    .padding(10)
                                }
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text("Tap 'Next Wallpaper' to discover anime art")
                                        .font(.footnote)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }

                            if isLoading {
                                Color.black.opacity(0.4)
                                    .cornerRadius(24)
                                ProgressView()
                                    .tint(Color(red: 1.0, green: 0.45, blue: 0.65))
                                    .scaleEffect(1.4)
                            }
                        }
                        .frame(height: 480)
                        .padding(.horizontal)

                        // Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                fetchNextWallpaper()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Next Wallpaper")
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.42, blue: 0.60), Color(red: 0.90, green: 0.25, blue: 0.50)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color(red: 1.0, green: 0.42, blue: 0.60).opacity(0.3), radius: 8, y: 4)
                            }
                            .disabled(isLoading)

                            Button {
                                saveCurrentWallpaperToPhotos()
                            } label: {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 50)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(16)
                            }
                            .disabled(currentItem == nil)
                        }
                        .padding(.horizontal)

                        Spacer(modifier = Modifier.height(20))
                    }
                }

                // Toast Notification
                if showToast, let msg = toastMessage {
                    VStack {
                        Spacer()
                        Text(msg)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(25)
                            .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showShortcutsGuide) {
                ShortcutsGuideView()
            }
        }
    }

    private func fetchNextWallpaper() {
        isLoading = true
        Task {
            do {
                let config = AppConfig(query: query, sfwOnly: sfwOnly)
                let items = try await WallhavenService.shared.searchWallpapers(config: config)
                if let selected = items.randomElement() {
                    currentItem = selected
                } else {
                    showToastNotification("No wallpapers found.")
                }
            } catch {
                showToastNotification("Error loading wallpapers.")
            }
            isLoading = false
        }
    }

    private func saveCurrentWallpaperToPhotos() {
        guard let item = currentItem, let url = URL(string: item.path) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                let success = try await PhotoSaver.shared.saveImageToPhotos(image: image)
                if success {
                    showToastNotification("✨ Saved to Photos successfully!")
                }
            } catch {
                showToastNotification("Failed to save image to Photos.")
            }
        }
    }

    private func showToastNotification(_ msg: String) {
        toastMessage = msg
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showToast = false }
        }
    }
}

// Lock Screen Mock Overlay
struct LockScreenMockOverlay: View {
    var body: some View {
        VStack {
            Spacer().frame(height: 30)
            Image(systemName: "lock.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.9))
            Text("Wednesday, October 10")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            Text("9:41")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            HStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "flashlight.off.fill").foregroundColor(.white))
                Spacer()
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "camera.fill").foregroundColor(.white))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }
}

// Home Screen Mock Overlay
struct HomeScreenMockOverlay: View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 4)

    var body: some View {
        VStack {
            Spacer().frame(height: 60)
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(0..<12) { _ in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

// Siri Shortcuts Automation Guide Sheet
struct ShortcutsGuideView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Automate Wallpaper with Siri Shortcuts")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Because iOS does not allow direct background wallpaper switching by third-party apps, you can use Apple Shortcuts to rotate wallpapers automatically at any scheduled interval!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 14) {
                        StepRow(number: "1", title: "Open Apple Shortcuts app", subtitle: "Go to the Automation tab and tap '+' to create a Personal Automation.")
                        StepRow(number: "2", title: "Choose Trigger", subtitle: "Select 'Time of Day' (e.g. 8:00 AM daily), 'When charging', or 'When waking up'.")
                        StepRow(number: "3", title: "Add 'Get Next Anime Wallpaper'", subtitle: "Search for 'Anime Wallpaper' actions and add 'Get Next Anime Wallpaper'.")
                        StepRow(number: "4", title: "Add 'Set Wallpaper' action", subtitle: "Connect the result to iOS built-in 'Set Wallpaper' action.")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Automation Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StepRow: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Color(red: 1.0, green: 0.42, blue: 0.60))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
    }
}
