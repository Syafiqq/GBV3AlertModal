// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
// tools 6.0 => Swift 6 language mode is the default for all targets (strict concurrency = errors).

import PackageDescription

let package = Package(
    name: "GBV3AlertModal",
    platforms: [
        .iOS(.v15)
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
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GBV3AlertModal",
            dependencies: [
                "SnapKit"
            ],
            path: "Library/GBV3AlertModal/Sources",
            resources: [
                .process("GBV3AlertModal/Assets.xcassets"),
            ],
            // No swiftSettings needed: tools-version 6.0 makes Swift 6 the default language mode
            // for every target here, so strict-concurrency violations are compile ERRORS.
            plugins: [
            ]
        ),
        .testTarget(
            name: "GBV3AlertModalTests",
            dependencies: [
                "GBV3AlertModal",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Library/GBV3AlertModal/Tests/GBV3AlertModalTests",
            // An asset catalog the TEST bundle owns, so a banner can finally be compared. Both
            // renderers resolve artwork from the main bundle by default and this target has none,
            // which is why `bannerIsUnresolvableInTheLibraryBundle` excluded every banner from the
            // one gate that measures the two backends against each other.
            resources: [.process("Resources")],
            plugins: [
            ]
        )
    ]
)
