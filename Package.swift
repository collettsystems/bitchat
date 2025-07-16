// swift-tools-version: 5.9

import PackageDescription

var supportedPlatforms: [SupportedPlatform] = [
    .iOS(.v16),
    .macOS(.v13)
]
#if os(Windows)
 supportedPlatforms.append(.windows(.v10))
#endif

var packageDependencies: [Package.Dependency] = []
#if os(Windows)
 packageDependencies.append(.package(url: "https://github.com/jedisct1/swift-sodium.git", from: "0.9.1"))
#endif

var targetDependencies: [Target.Dependency] = []
#if os(Windows)
 targetDependencies.append(.product(name: "Sodium", package: "swift-sodium"))
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
    dependencies: packageDependencies,
    targets: [
        .executableTarget(
            name: "bitchat",
            dependencies: targetDependencies,
            path: "bitchat"
        )
    ]
)
