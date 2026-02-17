// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ApinatorSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "ApinatorSDK", targets: ["ApinatorSDK"])
    ],
    targets: [
        .target(name: "ApinatorSDK"),
        .testTarget(name: "ApinatorSDKTests", dependencies: ["ApinatorSDK"])
    ]
)
