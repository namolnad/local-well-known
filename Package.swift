// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "local-well-known",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "local-well-known", targets: ["LocalWellKnown"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/namolnad/swifter", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "LocalWellKnown",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Swifter", package: "swifter"),
            ]
        ),
        .testTarget(
            name: "LocalWellKnownTests",
            dependencies: ["LocalWellKnown"]
        ),
    ]
)
