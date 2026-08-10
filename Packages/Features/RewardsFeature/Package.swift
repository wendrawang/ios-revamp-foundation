// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RewardsFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "RewardsFeature", targets: ["RewardsFeature"])],
    dependencies: [
        .package(path: "../../DesignSystem"),
        .package(path: "../../PlatformKit"),
    ],
    targets: [
        .target(
            name: "RewardsFeature",
            dependencies: ["DesignSystem", .product(name: "CoreNetworking", package: "PlatformKit")],
            path: "Sources"
        ),
        .testTarget(
            name: "RewardsFeatureTests",
            dependencies: [
                "RewardsFeature",
                .product(name: "CoreNetworking", package: "PlatformKit"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
