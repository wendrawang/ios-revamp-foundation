// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SecureWebKit",
    platforms: [.iOS(.v16)],
    products: [.library(name: "SecureWebKit", targets: ["SecureWebKit"])],
    dependencies: [.package(path: "../PlatformKit")],
    targets: [
        .target(
            name: "SecureWebKit",
            dependencies: [.product(name: "CoreLogging", package: "PlatformKit")]
        ),
        .testTarget(
            name: "SecureWebKitTests",
            dependencies: ["SecureWebKit", .product(name: "CoreLogging", package: "PlatformKit")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
