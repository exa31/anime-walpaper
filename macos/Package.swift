// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnimeWallpaper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AnimeWallpaper", targets: ["AnimeWallpaper"])
    ],
    targets: [
        .executableTarget(
            name: "AnimeWallpaper",
            path: "Sources"
        )
    ]
)
