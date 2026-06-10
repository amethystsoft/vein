import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

extension RelationshipTest {
    // Example Schema: Tag (inverse: "posts") <-> Post (inverse: "tags")
    @Test func testManyToManyInsertAndClear() async throws {
        let dbPath = try prepareContainerLocation(name: "ManyMandInsertAndClear")
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        let post = V0_0_1.Post(title: "Swift Optimization")
        let tagSwift = V0_0_1.Tag(name: "Swift")
        let tagPerformance = V0_0_1.Tag(name: "Performance")
        
        try container.context.insert(post)
        post.tags.append(contentsOf: [tagSwift, tagPerformance])
        try container.context.save()
        
        #expect(tagSwift.posts.contains(where: { $0.id == post.id }))
        
        // Verify removal clean-up
        post.tags.remove(at: 0)
        try container.context.save()
        #expect(tagSwift.posts.isEmpty)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Tag.self, Post.self]
    
    @Model
    final class Tag: Identifiable {
        @Field
        var name: String
        
        @Relationship(inverse: "tags")
        var posts: [Post]
        
        init(name: String) {
            self.name = name
        }
    }
    
    @Model
    final class Post: Identifiable {
        @Relationship(inverse: "posts")
        var tags: [Tag]
        
        @Field
        var title: String
        
        init(title: String) {
            self.title = title
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {[]}
}
