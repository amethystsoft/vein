import Foundation
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

        @LazyField
        var attachment: Data?

        init(title: String, content: String) {
            self.title = title
            self.content = content
        }
    }
}

typealias Post = V0_0_1.Post

enum Migration: SchemaMigrationPlan {
    static let schemas: [VersionedSchema.Type] = [
        V0_0_1.self
    ]

    static let stages: [MigrationStage] = []
}
