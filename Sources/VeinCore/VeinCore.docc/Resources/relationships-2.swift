import Foundation
import VeinCore

enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any PersistentModel.Type] = [
        Post.self, Attachment.self
    ]
    
    @Model
    final class Post {
        var title: String
        var content: String
        
        @Relationship(
            inverse: \Attachment.post,
            deleteRule: .cascade
        )
        var attachments: [Attachment]
        
        init(title: String, content: String) {
            self.title = title
            self.content = content
        }
    }
    
    @Model
    final class Attachment {
        @Relationship
        var post: Post?
        
        var name: String
        var fileType: FileType
        var sizeMiB: Double
        
        @LazyField
        var data: Data?
        
        init(name: String, fileType: FileType, data: Data) {
            self.name = name
            self.fileType = fileType
            self.sizeMiB = Double(data.count) / 1024 / 1024
            self.data = data
        }
        
        enum FileType: String, RawRepresentablePersistable {
            case png
            case jpg
            case gif
            case swift
            // ...
        }
    }
}

typealias Post = V0_0_1.Post
typealias Attachment = V0_0_1.Attachment

enum Migration: SchemaMigrationPlan {
    static let schemas: [VersionedSchema.Type] = [
        V0_0_1.self
    ]
    
    static let stages: [MigrationStage] = []
}
