// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport
import Foundation

#if os(macOS)
    let testSwiftUI = ProcessInfo.processInfo.environment["TEST_SWIFTUI"] != nil

    let veinAPIToTestDependencies: [Target.Dependency] = testSwiftUI ?
        ["VeinSwiftUI", "VeinSwiftUIMacros"]:
        ["VeinCore", "VeinCoreMacros"]

    let testSwiftSettings: [SwiftSetting] = testSwiftUI ? [.define("TEST_SWIFTUI")] : []
#else
    let veinAPIToTestDependencies: [Target.Dependency] = ["VeinCore", "VeinCoreMacros"]
    let testSwiftSettings: [SwiftSetting] = []
#endif

var veinDependencies: [Target.Dependency] = [
    .product(name: "Crypto", package: "swift-crypto"),
    .product(name: "SQLiteDB", package: "swift-sqlcipher"),
    "ULID",
    .product(name: "Logging", package: "swift-log"),
    .product(
        name: "KeychainAccess",
        package: "keychainaccess",
        condition: .when(platforms: [.iOS, .macOS, .tvOS, .visionOS, .watchOS]),
    ),
    .product(
        name: "KeyringAccess",
        package: "KeyringAccess",
        condition: .when(platforms: [.linux])
    ),
    .product(name: "Atomics", package: "swift-atomics"),
    .product(
        name: "SwiftCrossUI",
        package: "swift-cross-ui",
        condition: .when(traits: ["VeinSCUI"])
    )
]

let package = Package(
    name: "amethyst-vein",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .macCatalyst(.v17), .visionOS(.v1)],
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
            name: "VeinSwiftUI",
            targets: ["VeinSwiftUI"]
        ),
        .library(
            name: "VeinSCUI",
            targets: ["VeinSCUI"]
        ),
        .library(
            name: "VeinTesting",
            targets: ["VeinTesting"]
        ),
        .library(
            name: "ULID",
            targets: ["ULID"]
        ),
    ],
    traits: [
        .trait(name: "VeinSCUI")
    ],
    dependencies: [
        // SQLite >= 3.45.0 is required to support JSONB.
        // The bundled version of swift-sqlcipher >= 1.9.0 matches that requirement.
        .package(
            url: "https://github.com/skiptools/swift-sqlcipher",
            .upToNextMajor(from: "1.11.0")
        ),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "610.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.9.1")),
        .package(
            url: "https://github.com/kishikawakatsumi/keychainaccess",
            .upToNextMajor(from: "4.2.2")
        ),
        .package(
            url: "https://github.com/amethystsoft/KeyringAccess",
            .upToNextMajor(from: "1.0.0")
        ),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.3.1")),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"),
        .package(url: "https://github.com/typelift/SwiftCheck", .upToNextMinor(from: "0.12.0")),
        .package(url: "https://github.com/moreSwift/swift-cross-ui", .upToNextMinor(from: "0.8.0"))
    ],
    targets: [
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
            name: "VeinSwiftUI",
            dependencies: [
                "Vein",
                "VeinSwiftUIMacros"
            ]
        ),
        .target(
            name: "VeinSCUI",
            dependencies: [
                "Vein",
                "VeinSCUIMacros",
                .product(
                    name: "SwiftCrossUI",
                    package: "swift-cross-ui",
                    condition: .when(traits: ["VeinSCUI"])
                )
            ]
        ),
        .target(
            name: "VeinTesting",
            dependencies: [
                "VeinCore"
            ]
        ),
        .macro(
            name: "VeinCoreMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "VeinMacrosCore",
            ]
        ),
        .macro(
            name: "VeinSwiftUIMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "VeinMacrosCore",
            ]
        ),
        .macro(
            name: "VeinSCUIMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "VeinMacrosCore",
            ]
        ),
        .target(
            name: "VeinMacrosCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(name: "ULID"),
        .testTarget(
            name: "VeinTests",
            dependencies: [
                "Vein",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SQLiteDB", package: "swift-sqlcipher"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
                .product(
                    name: "SwiftCheck",
                    package: "SwiftCheck",
                    condition: .when(platforms: [.macOS, .linux])
                )
            ] + veinAPIToTestDependencies,
            swiftSettings: testSwiftSettings
        ),
        .testTarget(
            name: "VeinTestingTests",
            dependencies: [
                "VeinTesting",
                "Vein",
                .product(name: "Logging", package: "swift-log")
            ] + veinAPIToTestDependencies,
            swiftSettings: testSwiftSettings
        ),
        .testTarget(
            name: "ULIDTests",
            dependencies: ["ULID"]
        )
    ]
)
