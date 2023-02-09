// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "lwk",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "lwk", targets: ["LocalWellKnown"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/namolnad/swifter", from: "2.0.0"),
//        .package(url: "https://github.com/orlandos-nl/Citadel", from: "0.4.11"),
    ],
    targets: [
        .executableTarget(
            name: "LocalWellKnown",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Swifter", package: "swifter"),
//                .product(name: "Citadel", package: "Citadel"),
            ]
        ),
        .testTarget(
            name: "LocalWellKnownTests",
            dependencies: ["LocalWellKnown"]
        ),
    ]
)
