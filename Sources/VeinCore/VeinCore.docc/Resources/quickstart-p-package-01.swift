// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
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
