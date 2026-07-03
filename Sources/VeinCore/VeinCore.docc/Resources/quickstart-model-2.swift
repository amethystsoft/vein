import VeinCore

enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any PersistentModel.Type] = [
        Post.self
    ]
    
    @Model
    final class Post {
        var title: String
        var content: String
    }
}
