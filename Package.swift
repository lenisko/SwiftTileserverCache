// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SwiftTileserverCache",
    platforms: [
        .macOS(.v12) // linux does not yet have runtime availability checks so this doesn't apply to linux yet
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", .upToNextMinor(from: "4.119.2")),
        .package(url: "https://github.com/vapor/leaf", .upToNextMinor(from: "4.5.1")),
        .package(url: "https://github.com/JohnSundell/ShellOut", .upToNextMinor(from: "2.3.0")),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.20"))
    ],
    targets: [
        .target(
            name: "SwiftTileserverCache",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "ShellOut", package: "ShellOut"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .executableTarget(
            name: "SwiftTileserverCacheApp",
            dependencies: [
                .target(name: "SwiftTileserverCache"),
            ]
        ),
        .testTarget(
            name: "SwiftTileserverCacheTests",
            dependencies: [
                .target(name: "SwiftTileserverCache"),
            ]
        )
    ]
)
