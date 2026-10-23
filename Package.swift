// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PipCreator",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CreatorCore", targets: ["CreatorCore"]),
        .executable(name: "PipCreator", targets: ["CreatorApp"])
    ],
    targets: [
        .target(name: "CreatorCore"),
        .executableTarget(name: "CreatorApp", dependencies: ["CreatorCore"]),
        .testTarget(name: "CreatorCoreTests", dependencies: ["CreatorCore"])
    ]
)
