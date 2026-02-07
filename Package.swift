// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ProntoProvisioningSDK",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ProntoProvisioningSDK",
            targets: ["ProntoProvisioningSDK"]
        ),
    ],
    targets: [
        .target(
            name: "ProntoProvisioningSDK",
            dependencies: [],
            path: "Sources/ProntoProvisioningSDK"
        ),
        .testTarget(
            name: "ProntoProvisioningSDKTests",
            dependencies: ["ProntoProvisioningSDK"],
            path: "Tests/ProntoProvisioningSDKTests"
        ),
    ]
)
