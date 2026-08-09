// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UpgradeServiceFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "UpgradeServiceFeature", targets: ["UpgradeServiceFeature"])],
    dependencies: [.package(path: "../../DesignSystem")],
    targets: [
        .target(name: "UpgradeServiceFeature", dependencies: ["DesignSystem"], path: "Sources"),
        .testTarget(name: "UpgradeServiceFeatureTests", dependencies: ["UpgradeServiceFeature"], path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)

