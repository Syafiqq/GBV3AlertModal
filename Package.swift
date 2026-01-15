// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GBV3AlertModal",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "GBV3AlertModal",
            targets: ["GBV3AlertModal"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.0"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.57.0"),
    ],
    targets: [
        .target(
            name: "GBV3AlertModal",
            dependencies: [
                "SnapKit"
            ],
            path: "Sources/GBV3AlertModal/GBV3AlertModal",
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .testTarget(
            name: "GBV3AlertModalTests",
            dependencies: [
                "GBV3AlertModal",
            ],
            path: "Sources/GBV3AlertModal/GBV3AlertModalTests",
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        )
    ]
)
