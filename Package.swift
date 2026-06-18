// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

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
    )
]

var targets: [Target] = [
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
        name: "VeinSwiftUI",
        dependencies: [
            "Vein",
            "VeinSwiftUIMacros"
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
            .product(name: "VeinMacrosCore", package: "VeinMacrosCore"),
        ]
    ),
    .macro(
        name: "VeinSwiftUIMacros",
        dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            .product(name: "VeinMacrosCore", package: "VeinMacrosCore"),
        ]
    ),
    .target(
        name: "VeinMacrosBaseWrapper",
        dependencies: [
            .product(name: "VeinMacrosCore", package: "VeinMacrosCore")
        ],
    ),
    .target(name: "ULID"),
    .testTarget(
        name: "VeinTests",
        dependencies: [
            "Vein",
            "VeinCore",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "SQLiteDB", package: "swift-sqlcipher"),
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
        ]
    ),
    .testTarget(
        name: "VeinTestingTests",
        dependencies: [
            "VeinTesting",
            "Vein",
            "VeinCore",
            "VeinCoreMacros",
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "Logging", package: "swift-log")
        ]
    ),
]
#if os(macOS)
targets.append(
    .testTarget(
        name: "ULIDTests",
        dependencies: ["ULID"]
    )
)
#endif

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
            name: "VeinMacrosBase",
            targets: ["VeinMacrosBaseWrapper"]
        ),
        .library(
            name: "VeinTesting",
            targets: ["VeinTesting"]
        ),
        .library(
            name: "ULID",
            targets: ["ULID"]
        )
    ],
    dependencies: [
        .package(path: "./VeinMacrosCore"),
        // SQLite >= 3.45.0 is required to support JSONB.
        // The bundled version of swift-sqlcipher >= 1.9.0 matches that requirement.
            .package(
                url: "https://github.com/skiptools/swift-sqlcipher",
                .upToNextMajor(from: "1.9.0")
            ),
        .package(url: "https://github.com/apple/swift-crypto.git", "1.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "610.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.9.1")),
        .package(url: "https://github.com/kishikawakatsumi/keychainaccess", .upToNextMajor(from: "4.2.2")),
        .package(url: "https://github.com/amethystsoft/KeyringAccess", .upToNextMajor(from: "1.0.0")),
    ],
    targets: targets
)
