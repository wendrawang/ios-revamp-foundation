// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DashboardFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "DashboardFeature", targets: ["DashboardFeature"])],
    dependencies: [.package(path: "../../DesignSystem")],
    targets: [
        .target(name: "DashboardFeature", dependencies: ["DesignSystem"], path: "Sources"),
        .testTarget(name: "DashboardFeatureTests", dependencies: ["DashboardFeature"], path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)
