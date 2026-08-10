// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ScanFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "ScanFeature", targets: ["ScanFeature"])],
    dependencies: [.package(path: "../../DesignSystem")],
    targets: [
        .target(name: "ScanFeature", dependencies: ["DesignSystem"], path: "Sources"),
        .testTarget(name: "ScanFeatureTests", dependencies: ["ScanFeature"], path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)
