import VeinCore

func fetchPostsMentioningSwiftSortedByTitle(
    page: Int,
    _ context: ManagedObjectContext
) throws -> [Post] {
    let fetchDescriptor = try FetchDescriptor(
        predicate: #Predicate<Post> { post in
            post.content.contains("Swift")
        },
        sortBy: [SortRule(\.title)]
    )
    
    return try context.fetch(fetchDescriptor)
}
