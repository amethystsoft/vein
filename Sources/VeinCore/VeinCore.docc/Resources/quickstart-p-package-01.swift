// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
// Licensed under Mozilla Public License v2.0
//
// See LICENSE.txt for license information
//
// ===----------------------------------------------------------------------===

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
