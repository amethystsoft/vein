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
