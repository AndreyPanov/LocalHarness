// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocalHarness",
    platforms: [
        .macOS(.v14)
        ],
    products: [
        .library(
            name: "HarnessCore",
            targets: ["HarnessCore"]
        ),
        .executable(
            name: "harness",
            targets: ["HarnessCLI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            from: "1.7.0"
        )
        ],
    targets: [
        .target(
            name: "HarnessCore"
        ),
        .executableTarget(
            name: "HarnessCLI",
            dependencies: [
                "HarnessCore",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                )
            ]
        ),
        .testTarget(
            name: "LocalHarnessTests",
            dependencies: ["LocalHarness"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
