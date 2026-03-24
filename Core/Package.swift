// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "GarbagemanCore",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "GarbagemanCore",
            targets: ["GarbagemanCore"]
        ),
    ],
    targets: [
        .target(
            name: "GarbagemanCore"
        ),
        .testTarget(
            name: "GarbagemanCoreTests",
            dependencies: ["GarbagemanCore"]
        ),
    ]
)
