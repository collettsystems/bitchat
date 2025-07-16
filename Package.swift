// swift-tools-version: 5.9

import PackageDescription

var supportedPlatforms: [SupportedPlatform] = [
    .iOS(.v16),
    .macOS(.v13)
]
#if os(Windows)
supportedPlatforms.append(.windows(.v10))
#endif

let package = Package(
    name: "bitchat",
    platforms: supportedPlatforms,
    products: [
        .executable(
            name: "bitchat",
            targets: ["bitchat"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "bitchat",
            path: "bitchat"
        ),
    ]
)
