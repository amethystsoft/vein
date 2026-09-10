import VeinCore

func fetchPostsMentioningSwiftSortedByTitle(
    page: Int,
    _ context: ManagedObjectContext
) -> [Post] {
    let fetchDescriptor = PaginatedFetchDescriptor(
        predicate: #Predicate<Post> { post in
            post.content.contains("Swift")
        },
        sortBy: [SortRule(\.title)],
        limit: 20,
        offset: page * 20
    )
    
    return context.fetch(fetchDescriptor)
}
