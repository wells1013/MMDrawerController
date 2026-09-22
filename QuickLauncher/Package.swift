// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickLauncher",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "QuickLauncher",
            path: "Sources/QuickLauncher"
        )
    ]
)
