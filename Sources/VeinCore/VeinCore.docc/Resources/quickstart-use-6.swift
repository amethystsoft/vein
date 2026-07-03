import VeinCore

func setupAndUseVein() throws {
    let container = ModelContainer(
        V0_0_1.self, // Your VersionedSchema
        migration: Migration.self, // Your SchemaMigrationPlan
        at: "path/to/db.sqlite3", // or nil for in memory
        appID: "com.example.app" // The id of your app
    )
    
    try container.migrate()
    
    let post = Post(title: "How to use Vein?", content: "It's very easy.")
    try container.context.insert(post)
    
    post.content = "What did I tell you?"
    
    try container.context.save()
    
    let posts = try container.context.fetchAll(#Predicate<Post> { post in
        post.title.contains("Vein")
    }) // gives back [post]
}
