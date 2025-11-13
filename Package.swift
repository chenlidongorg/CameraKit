// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CameraKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "CameraKit",
            targets: ["CameraKit"]
        ),
    ],
    targets: [
        .target(
            name: "CameraKit",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CameraKitTests",
            dependencies: ["CameraKit"]
        ),
    ]
)
