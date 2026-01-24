// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GBV3AlertModal",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GBV3AlertModal",
            targets: ["GBV3AlertModal"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GBV3AlertModal",
            dependencies: [
                "SnapKit"
            ],
            path: "Library/GBV3AlertModal/Sources/GBV3AlertModal",
            plugins: [
            ]
        ),
        .testTarget(
            name: "GBV3AlertModalTests",
            dependencies: [
                "GBV3AlertModal",
            ],
            path: "Library/GBV3AlertModal/Tests/GBV3AlertModalTests",
            plugins: [
            ]
        )
    ]
)
