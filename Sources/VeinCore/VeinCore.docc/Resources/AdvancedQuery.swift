import VeinCore

func fetchPostsMentioningSwiftSortedByTitle(_ context: ManagedObjectContext) -> [Post] {
    let fetchDescriptor = FetchDescriptor(
        predicate: #Predicate<Post> { post in
            post.content.contains("Swift")
        }
    )
}
