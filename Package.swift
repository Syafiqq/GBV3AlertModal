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
        .library(name: "GBV3AlertModal", targets: ["GBV3AlertModal"]),
        .library(name: "GBV3AlertModalCore", targets: ["GBV3AlertModalCore"]),
        .library(name: "GBV3AlertModalSwiftUI", targets: ["GBV3AlertModalSwiftUI"]),
        .library(name: "GBV3AlertModalUIKit", targets: ["GBV3AlertModalUIKit"]),
        .library(name: "GBV3AlertModalMigration", targets: ["GBV3AlertModalMigration"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "GBV3AlertModalCore",
            path: "Library/GBV3AlertModal/Sources/GBV3AlertModalCore"
        ),
        .target(
            name: "GBV3AlertModalSwiftUI",
            dependencies: ["GBV3AlertModalCore"],
            path: "Library/GBV3AlertModal/Sources/GBV3AlertModalSwiftUI",
            resources: [.process("Assets.xcassets")]
        ),
        .target(
            name: "GBV3AlertModalUIKit",
            dependencies: [
                "GBV3AlertModalCore",
                "SnapKit",
            ],
            path: "Library/GBV3AlertModal/Sources/GBV3AlertModalUIKit",
            resources: [.process("Assets.xcassets")]
        ),
        .target(
            name: "GBV3AlertModalMigration",
            dependencies: [
                "GBV3AlertModalCore",
                "GBV3AlertModalSwiftUI",
                "GBV3AlertModalUIKit",
            ],
            path: "Library/GBV3AlertModal/Sources/GBV3AlertModalMigration"
        ),
        .target(
            name: "GBV3AlertModal",
            dependencies: [
                "GBV3AlertModalCore",
                "GBV3AlertModalSwiftUI",
                "GBV3AlertModalUIKit",
                "GBV3AlertModalMigration",
            ],
            path: "Library/GBV3AlertModal/Sources/GBV3AlertModal"
        ),
        .testTarget(
            name: "GBV3AlertModalCoreTests",
            dependencies: ["GBV3AlertModalCore"],
            path: "Library/GBV3AlertModal/Tests/GBV3AlertModalCoreTests"
        ),
        .testTarget(
            name: "GBV3AlertModalSwiftUITests",
            dependencies: ["GBV3AlertModalCore", "GBV3AlertModalSwiftUI"],
            path: "Library/GBV3AlertModal/Tests/GBV3AlertModalSwiftUITests",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GBV3AlertModalUIKitTests",
            dependencies: ["GBV3AlertModalCore", "GBV3AlertModalUIKit"],
            path: "Library/GBV3AlertModal/Tests/GBV3AlertModalUIKitTests"
        ),
        .testTarget(
            name: "GBV3AlertModalMigrationTests",
            dependencies: [
                "GBV3AlertModalCore",
                "GBV3AlertModalSwiftUI",
                "GBV3AlertModalUIKit",
                "GBV3AlertModalMigration",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Library/GBV3AlertModal/Tests/GBV3AlertModalMigrationTests",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GBV3AlertModalArchitectureTests",
            dependencies: [
                "GBV3AlertModalCore",
                "GBV3AlertModalSwiftUI",
                "GBV3AlertModalUIKit",
                "GBV3AlertModalMigration",
            ],
            path: "Library/GBV3AlertModal/Tests/GBV3AlertModalArchitectureTests"
        ),
        .testTarget(
            name: "GBV3AlertModalCompatibilityTests",
            dependencies: ["GBV3AlertModal"],
            path: "Library/GBV3AlertModal/Tests/GBV3AlertModalCompatibilityTests"
        )
    ]
)
