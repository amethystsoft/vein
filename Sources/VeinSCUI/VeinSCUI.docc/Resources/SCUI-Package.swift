// swift-tools-version: 6.2

import PackageDescription

let dependencies: [Target.Dependency] = [
    .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
    .product(name: "DefaultBackend", package: "swift-cross-ui"),
    .product(name: "VeinSCUI", package: "vein"),
]

let package = Package(
    name: "YourApp",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .macCatalyst(.v17), .visionOS(.v1)],
    dependencies: [
        .package(
            url: "https://github.com/moreSwift/swift-cross-ui.git",
            .upToNextMinor(from: "0.8.0")
        ),
        .package(
            url: "https://github.com/amethystsoft/vein.git",
            .upToNextMajor(from: "1.0.0"),
            traits: ["VeinSCUI"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "YourApp",
            dependencies: dependencies
        )
    ]
)
