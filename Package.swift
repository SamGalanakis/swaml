// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SWAML",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "SWAML",
            targets: ["SWAML"]
        ),
    ],
    targets: [
        .target(
            name: "SWAML",
            dependencies: [],
            path: "Sources/SWAML"
        ),
        .testTarget(
            name: "SWAMLTests",
            dependencies: ["SWAML"],
            path: "Tests/SWAMLTests"
        ),
    ]
)
