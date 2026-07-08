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

import SwiftUI
import VeinSwiftUI

@main
struct VeinTestEnvironmentApp: App {
    let modelContainer: ModelContainer

    init() {
        // Initialize ModelContainer
        self.modelContainer = initializedModelContainer
    }

    var body: some Scene {
        WindowGroup("VeinExample") {
            ContentView()
        }
    }
}
