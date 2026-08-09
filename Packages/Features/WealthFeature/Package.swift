// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WealthFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "WealthFeature", targets: ["WealthFeature"])],
    dependencies: [
        .package(path: "../../DesignSystem"),
        .package(path: "../../PlatformKit"),
    ],
    targets: [
        .target(
            name: "WealthFeature",
            dependencies: ["DesignSystem", .product(name: "CoreNetworking", package: "PlatformKit")],
            path: "Sources"
        ),
        .testTarget(name: "WealthFeatureTests", dependencies: ["WealthFeature"], path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)

