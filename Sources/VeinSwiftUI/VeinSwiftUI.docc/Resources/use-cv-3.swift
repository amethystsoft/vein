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
