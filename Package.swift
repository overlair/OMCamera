// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OMCamera",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OMCamera",
            targets: ["OMCamera"]),
    ],
    dependencies: [
            .package(url: "https://github.com/MetalPetal/VideoIO.git", from: "2.3.1"),
            .package(url: "https://github.com/MetalPetal/MetalPetal.git", from: "1.25.2")
        ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OMCamera",
            dependencies: [
                .product(name: "VideoIO", package: "VideoIO"),
                .product(name: "MetalPetal", package: "MetalPetal")
            ]
        ),
        .testTarget(
            name: "OMCameraTests",
            dependencies: ["OMCamera"]),
    ]
)
