// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

var veinDependencies: [Target.Dependency] = [
    .product(name: "Crypto", package: "swift-crypto"),
    .product(name: "SQLiteDB", package: "swift-sqlcipher"),
    .product(name: "ULID", package: "ULID.swift")
]

#if canImport(AppKit) || canImport(UIKit)
    veinDependencies.append(.product(name: "KeychainAccess", package: "keychainaccess"))
#endif

let package = Package(
    name: "amethyst-vein",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .macCatalyst(.v16), .visionOS(.v1)],
    products: [
        .library(
            name: "Vein",
            targets: ["Vein"]
        ),
        .library(
            name: "VeinCore",
            targets: ["VeinCore"]
        ),
        .library(
            name: "VeinTesting",
            targets: ["VeinTesting"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/skiptools/swift-sqlcipher",
            .upToNextMajor(from: "1.9.0")
        ),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "610.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.9.1")),
        .package(url: "https://github.com/yaslab/ULID.swift", .upToNextMajor(from: "1.3.1")),
        .package(url: "https://github.com/kishikawakatsumi/keychainaccess", .upToNextMajor(from: "4.2.2"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Vein",
            dependencies: veinDependencies
        ),
        .target(
            name: "VeinCore",
            dependencies: [
                "Vein",
                "VeinCoreMacros",
            ]
        ),
        .target(
            name: "VeinTesting",
            dependencies: [
                "Vein"
            ]
        ),
        .macro(
            name: "VeinCoreMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "VeinTests",
            dependencies: [
                "Vein",
                "VeinCore",
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "VeinTestingTests",
            dependencies: [
                "VeinTesting",
                "Vein",
                "VeinCore",
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
