// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OKLCHColor",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [.library(name: "OKLCHColor", targets: ["OKLCHColor"])],
    targets: [
        .target(name: "OKLCHColor"),
        .testTarget(name: "OKLCHColorTests", dependencies: ["OKLCHColor"])
    ]
)
