// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "BetterSync",
    platforms: [.macOS(.v13), .iOS(.v14), .tvOS(.v14), .macCatalyst(.v14), .visionOS(.v1)],
    products: [
        .library(
            name: "BetterSync",
            targets: ["BetterSync"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.4"),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "601.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BetterSync",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ]
        ),
        .testTarget(
            name: "BetterSyncTests",
            dependencies: ["BetterSync"]
        ),
    ]
)
