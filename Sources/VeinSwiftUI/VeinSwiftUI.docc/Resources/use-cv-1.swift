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

struct ContentView: View {
    @Query var posts: [Post]

    var body: some View {
        List(posts) { post in
            Text(post.title)
        }
    }
}
