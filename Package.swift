// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "garbageman-app",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "garbageman",
            targets: ["GarbagemanDesktop"]
        ),
    ],
    dependencies: [
        .package(path: "./Core"),
    ],
    targets: [
        .executableTarget(
            name: "GarbagemanDesktop",
            dependencies: [
                .product(name: "GarbagemanCore", package: "Core"),
            ],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "GarbagemanDesktopTests",
            dependencies: [
                "GarbagemanDesktop",
                .product(name: "GarbagemanCore", package: "Core"),
            ]
        ),
    ]
)
