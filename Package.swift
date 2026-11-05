// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Heycast",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Heycast",
            path: "Sources/Heycast"
        ),
        .testTarget(
            name: "HeycastTests",
            dependencies: ["Heycast"]
        )
    ]
)
