// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FinancialHubFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "FinancialHubFeature", targets: ["FinancialHubFeature"])],
    dependencies: [.package(path: "../../DesignSystem")],
    targets: [
        .target(name: "FinancialHubFeature", dependencies: ["DesignSystem"], path: "Sources"),
        .testTarget(name: "FinancialHubFeatureTests", dependencies: ["FinancialHubFeature"], path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)

