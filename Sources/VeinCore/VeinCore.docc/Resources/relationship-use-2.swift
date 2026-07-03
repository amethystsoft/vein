import VeinCore

func tryRelationships(context: ManagedObjectContext) throws {
    let post = Post(
        title: "How to use Vein relationships?",
        content: "Again, it's pretty easy."
    )
    let attachment = Attachment(
        name: "ExampleFile",
        fileType: .swift,
        data: Data(bytes: [UInt8](repeating: 0, count: 1024 * 1024)) // very real swift file
    )
    
    // Relationships only work with context.
    try context.insert(post)
    // Added models get inserted automatically.
    post.attachments.append(attachment)
}
