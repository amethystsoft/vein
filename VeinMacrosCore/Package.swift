// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VeinMacrosCore",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .macCatalyst(.v16), .visionOS(.v1)],
    products: [
        .library(
            name: "VeinMacrosCore",
            targets: ["VeinMacrosCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "610.0.0"),
    ],
    targets: [
        .target(
            name: "VeinMacrosCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        )
    ]
)
