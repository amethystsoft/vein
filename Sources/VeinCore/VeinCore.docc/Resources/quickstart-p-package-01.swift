import PackageDescription

let package = Package(
    name: "YourPackage",
    products: [
        // ...
    ],
    dependencies: [
        .package(url: "https://github.com/amethystsoft/vein", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .executableTarget(
            name: "YourApp"
        )
    ]
)
