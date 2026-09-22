// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "lume",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "lume",
            path: "Sources/lume"
        )
    ]
)
