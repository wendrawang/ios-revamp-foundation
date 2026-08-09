// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TransferFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "TransferFeature", targets: ["TransferFeature"])],
    dependencies: [
        .package(path: "../../DesignSystem"),
        .package(path: "../../PlatformKit"),
    ],
    targets: [
        .target(
            name: "TransferFeature",
            dependencies: [
                "DesignSystem",
                .product(name: "CoreAnalytics", package: "PlatformKit"),
                .product(name: "CoreLogging", package: "PlatformKit"),
                .product(name: "CoreNetworking", package: "PlatformKit"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "TransferFeatureTests",
            dependencies: [
                "TransferFeature",
                .product(name: "CoreAnalytics", package: "PlatformKit"),
                .product(name: "CoreLogging", package: "PlatformKit"),
            ],
            path: "Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

