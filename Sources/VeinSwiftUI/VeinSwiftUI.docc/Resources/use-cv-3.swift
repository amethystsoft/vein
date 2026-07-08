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
    @Query(#Predicate<Post> { post in
        post.title.contains("Swift")
    })
    var posts: [Post]

    @Environment(\.modelContext) var context

    var body: some View {
        Button("Add post") {
            context.insert(Post(/* ... */))
        }
        List(posts) { post in
            Text(post.title)
        }
    }
}
