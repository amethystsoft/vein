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
