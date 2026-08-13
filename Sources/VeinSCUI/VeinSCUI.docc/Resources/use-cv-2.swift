import SwiftCrossUI
import VeinSCUI

struct ContentView: View {
    @Query(#Predicate<Post> { post in
        post.title.contains("Swift")
    })
    var posts: [Post]

    var body: some View {
        List(posts) { post in
            Text(post.title)
        }
    }
}
