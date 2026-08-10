// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MoreFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "MoreFeature", targets: ["MoreFeature"])],
    dependencies: [.package(path: "../../DesignSystem")],
    targets: [
        .target(name: "MoreFeature", dependencies: ["DesignSystem"], path: "Sources"),
        .testTarget(name: "MoreFeatureTests", dependencies: ["MoreFeature"], path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)
