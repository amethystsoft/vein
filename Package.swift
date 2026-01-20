// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

#if !os(Android) && !os(Windows) && !os(Linux)
let sqliteTraits: Package.Dependcy.Trait = ["SystemSQLite"]
#else
let sqliteTraits: Package.Dependcy.Trait = ["SwiftToolchainSQLite"]
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
            name: "CommonVeinMacroLogic",
            targets: ["CommonVeinMacroLogic"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/amethystsoft/SQLite.swift.git",
            branch: "master",
            traits: sqliteTraits
        ),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "610.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Vein",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "SQLite", package: "SQLite.swift"),
            ]
        ),
        .target(
            name: "VeinCore",
            dependencies: [
                "Vein",
                "VeinCoreMacros",
            ]
        ),
        .target(
            name: "CommonVeinMacroLogic",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .macro(
            name: "VeinCoreMacros",
            dependencies: [
                "CommonVeinMacroLogic",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "VeinTests",
            dependencies: [
                "Vein",
                "VeinCore"
            ]
        ),
    ]
)
