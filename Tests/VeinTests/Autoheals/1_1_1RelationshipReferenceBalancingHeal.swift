import Foundation
import Testing
import Logging
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct AutohealTests {
    func createSeededDB(from: String) throws -> Connection {
        let connection = try Connection()
        var pathToDump = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        pathToDump = pathToDump
            .appendingPathComponent("dumps")
            .appendingPathComponent("vein1_1_1RelationshipReferenceHealSeed-dump.sql")
        
        let data = try Data(contentsOf: pathToDump)
        try connection.execute(String(data: data, encoding: .utf8)!)
        
        return connection
    }
    
    @Test
    func checkFixed() throws {
        let connection = try createSeededDB(
            from: "vein1_1_1RelationshipReferenceHealSeed-dump.sql"
        )
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "lol",
            encryptionEnabled: false
        )
        
        let users = try container.context.fetchAll(V0_0_1.User.self)
        let mia = try #require(users.first { $0.name == "Mia" })
        let skyla = try #require(users.first { $0.name == "Skyla" })
        
        #expect(mia.comments.isEmpty)
        #expect(mia.extractPrimitiveState().values["comments"] as? [ULID] == [])
        #expect(skyla.comments.count == 1)
        #expect(skyla.extractPrimitiveState().values["comments"] as? [ULID]
                == [ULID(ulidString: "01M2XJTR40YV9PM6ZQ8H18TWBF")!])
        
        let comments = try container.context.fetchAll(V0_0_1.Comment.self)
        let comment = try #require(comments.first)
        #expect(comment.author === skyla)
        #expect(comment.extractPrimitiveState().values["author"] as? ULID? == skyla.id)
        #expect(comment.id.ulidString == "01M2XJTR40YV9PM6ZQ8H18TWBF")
        
        // MARK: -
        let tags = try container.context.fetchAll(V0_0_1.Tag.self)
        let swift = tags.first { $0.name == "Swift" }!
        let rust = tags.first { $0.name == "Rust" }!
        let php = tags.first { $0.name == "PHP" }!
        
        #expect(swift.posts.count == 2)
        #expect(swift.extractPrimitiveState().values["posts"] as? [ULID]
            == Array(repeating: ULID(ulidString: "01M2XN0AT3T6A8KJB0EVWPS9YT")!, count: 2)
        )
        #expect(rust.posts.count == 5)
        #expect(rust.extractPrimitiveState().values["posts"] as? [ULID]
            == Array(repeating: ULID(ulidString: "01M2XN0AT3TRP4QCXKF0WJD7SG")!, count: 5)
        )
        #expect(php.posts.count == 4)
        #expect(php.extractPrimitiveState().values["posts"] as? [ULID] == [
            ULID(ulidString: "01M2XN0AT3GY62TARFBZPT2Q3N")!,
            ULID(ulidString: "01M2XN0AT3GY62TARFBZPT2Q3N")!,
            ULID(ulidString: "01M2XN0AT3A3BEZ2S4J6RSTF4M")!,
            ULID(ulidString: "01M2XN0AT3A3BEZ2S4J6RSTF4M")!
        ])
        
        let posts = try container.context.fetchAll(V0_0_1.Post.self)
        let post0 = posts.first { $0.title == "Vein 1.0"}!
        let post1 = posts.first { $0.title == "Vein 1.1"}!
        let post2 = posts.first { $0.title == "Vein 1.2"}!
        let post3 = posts.first { $0.title == "Vein 1.3"}!
        
        #expect(post0.tags.count == 2)
        #expect(post0.extractPrimitiveState().values["tags"] as? [ULID]
            == Array(repeating: swift.id, count: 2)
        )
        #expect(post1.tags.count == 5)
        #expect(post1.extractPrimitiveState().values["tags"] as? [ULID]
                == Array(repeating: rust.id, count: 5)
        )
        #expect(post2.tags.count == 2)
        #expect(post2.extractPrimitiveState().values["tags"] as? [ULID]
                == Array(repeating: php.id, count: 2)
        )
        #expect(post3.tags.count == 2)
        #expect(post3.extractPrimitiveState().values["tags"] as? [ULID]
                == Array(repeating: php.id, count: 2)
        )
    }
}
fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [
        User.self,
        Comment.self,
        Post.self,
        Tag.self
    ]
    
    @Model
    final class User: Identifiable {
        @Field
        var name: String
        
        @Relationship(inverse: \Comment.author)
        var comments: [Comment]
        
        init(name: String) {
            self.name = name
        }
    }
    
    @Model
    final class Comment: Identifiable {
        @Relationship
        var author: User?
        
        @Field
        var text: String
        
        init(text: String) {
            self.text = text
        }
    }
    
    @Model
    final class Tag: Identifiable {
        @Field
        var name: String
        
        @Relationship(inverse: \Post.tags)
        var posts: Array<Post>
        
        init(name: String) {
            self.name = name
        }
    }
    
    @Model
    final class Post: Identifiable {
        @Relationship
        var tags: Array<Tag>
        
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
