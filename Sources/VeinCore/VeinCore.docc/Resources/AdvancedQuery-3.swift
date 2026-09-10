import VeinCore

func fetchPostsMentioningSwiftSortedByTitle(
    page: Int,
    _ context: ManagedObjectContext
) -> [Post] {
    let fetchDescriptor = FetchDescriptor(
        predicate: #Predicate<Post> { post in
            post.content.contains("Swift")
        },
        sortBy: [SortRule(\.title)]
    )
    
    return context.fetch(fetchDescriptor)
}
