// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PlatformKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "CoreLogging", targets: ["CoreLogging"]),
        .library(name: "CoreAnalytics", targets: ["CoreAnalytics"]),
        .library(name: "CoreFeatureFlags", targets: ["CoreFeatureFlags"]),
        .library(name: "CoreNetworking", targets: ["CoreNetworking"]),
        .library(name: "CoreSecurity", targets: ["CoreSecurity"]),
        .library(name: "CoreSession", targets: ["CoreSession"]),
    ],
    targets: [
        .target(name: "CoreLogging"),
        .target(name: "CoreAnalytics"),
        .target(name: "CoreFeatureFlags", dependencies: ["CoreLogging"]),
        .target(name: "CoreNetworking", dependencies: ["CoreLogging"]),
        .target(name: "CoreSecurity", dependencies: ["CoreNetworking", "CoreLogging"]),
        .target(name: "CoreSession", dependencies: ["CoreSecurity", "CoreLogging"]),
        .testTarget(
            name: "PlatformKitTests",
            dependencies: [
                "CoreLogging", "CoreAnalytics", "CoreFeatureFlags", "CoreNetworking", "CoreSecurity", "CoreSession",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
