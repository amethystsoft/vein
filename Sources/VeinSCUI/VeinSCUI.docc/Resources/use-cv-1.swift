import SwiftCrossUI
import VeinSCUI

struct ContentView: View {
    @Query var posts: [Post]

    var body: some View {
        List(posts) { post in
            Text(post.title)
        }
    }
}
