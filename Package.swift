// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenLaunch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenLaunch", targets: ["OpenLaunch"]),
        .library(name: "OpenLaunchCore", targets: ["OpenLaunchCore"])
    ],
    targets: [
        .target(
            name: "OpenLaunchCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "OpenLaunch",
            dependencies: ["OpenLaunchCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "OpenLaunchCoreTests",
            dependencies: ["OpenLaunchCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "OpenLaunchTests",
            dependencies: ["OpenLaunch"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
