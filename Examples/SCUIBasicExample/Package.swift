// swift-tools-version: 6.2

import PackageDescription

let exampleDependencies: [Target.Dependency] = [
    .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
    .product(name: "DefaultBackend", package: "swift-cross-ui"),
    .product(name: "VeinSCUI", package: "vein"),
]

let package = Package(
    name: "Examples",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .macCatalyst(.v17), .visionOS(.v1)],
    dependencies: [
        .package(url: "https://github.com/moreSwift/swift-cross-ui.git", .upToNextMinor(from: "0.8.0")),
        .package(path: "../../", traits: ["VeinSCUI"]),
    ],
    targets: [
        .executableTarget(
            name: "BasicExample",
            dependencies: exampleDependencies
        )
    ]
)
