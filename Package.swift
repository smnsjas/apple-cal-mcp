// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppleCalendarMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "apple-cal-mcp", targets: ["AppleCalendarMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "AppleCalendarMCP",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "AppleCalendarMCPTests",
            dependencies: ["AppleCalendarMCP"]
        )
    ]
)