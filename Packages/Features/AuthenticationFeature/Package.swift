// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AuthenticationFeature",
    platforms: [.iOS(.v16)],
    products: [.library(name: "AuthenticationFeature", targets: ["AuthenticationFeature"])],
    dependencies: [
        .package(path: "../../DesignSystem"),
        .package(path: "../../PlatformKit"),
    ],
    targets: [
        .target(
            name: "AuthenticationFeature",
            dependencies: [
                "DesignSystem",
                .product(name: "CoreSession", package: "PlatformKit"),
            ],
            path: "Sources"
        ),
        .testTarget(name: "AuthenticationFeatureTests", dependencies: ["AuthenticationFeature"], path: "Tests"),
    ],
    swiftLanguageModes: [.v6]
)

