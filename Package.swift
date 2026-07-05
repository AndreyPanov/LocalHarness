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
            name: "SocialSourceKit",
            targets: ["SocialSourceKit"]
        ),
        .library(
            name: "FileSystemKit",
            targets: ["FileSystemKit"]
        ),
        .library(
            name: "LocalLLMKit",
            targets: ["LocalLLMKit"]
        ),
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
            name: "SocialSourceKit"
        ),
        .target(
            name: "FileSystemKit"
        ),
        .target(
            name: "LocalLLMKit"
        ),
        .target(
            name: "MetalCrawlerCore",
            dependencies: [
                "SocialSourceKit",
                "FileSystemKit",
                "LocalLLMKit"
            ]
        ),
        .executableTarget(
            name: "MetalCrawlerCLI",
            dependencies: [
                "MetalCrawlerCore",
                "LocalLLMKit",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                )
            ]
        ),
        .testTarget(
            name: "MetalCrawlerTests",
            dependencies: [
                "MetalCrawlerCore",
                "SocialSourceKit",
                "FileSystemKit",
                "LocalLLMKit"
            ],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
