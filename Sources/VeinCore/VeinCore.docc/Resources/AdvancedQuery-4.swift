import VeinCore

func fetchPostsMentioningSwiftSortedByTitle(
    page: Int,
    _ context: ManagedObjectContext
) throws -> [Post] {
    let fetchDescriptor = try PaginatedFetchDescriptor(
        predicate: #Predicate<Post> { post in
            post.content.contains("Swift")
        },
        sortBy: [SortRule(\.title)],
        limit: 20,
        offset: page * 20
    )
    
    return try context.fetch(fetchDescriptor)
}
