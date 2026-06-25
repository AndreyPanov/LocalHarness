// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalCrawler",
    platforms: [
        .macOS(.v14)
        ],
    products: [
        .library(
            name: "MetalCrawlerCore",
            targets: ["MetalCrawlerCore"]
        ),
        .executable(
            name: "metal-crawler",
            targets: ["MetalCrawlerCLI"]
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
            name: "MetalCrawlerCore"
        ),
        .executableTarget(
            name: "MetalCrawlerCLI",
            dependencies: [
                "MetalCrawlerCore",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                )
            ]
        ),
        .testTarget(
            name: "MetalCrawlerTests",
            dependencies: ["MetalCrawlerCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
