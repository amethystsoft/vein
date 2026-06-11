import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

@MainActor
extension RelationshipTest {
    @Test(.timeLimit(.minutes(1)))
    func testDeleteCascade() async throws {
        let dbPath = try prepareContainerLocation(name: "DeleteCascade")
        
        Self.logger.info(
            "Relationship migration test started with db location: \(dbPath)"
        )
        
        let container = try ModelContainer(
            CommentRelationshipCascade.self,
            migration: CascadeMigration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        let user = CommentRelationshipCascade.User(name: "Mia")
        let comment = CommentRelationshipCascade.Comment(text: "Heyho")
        try container.context.insert(user)
        user.comments.append(comment)
        
        try container.context.save()
        
        #expect(user.comments.contains { $0.id == comment.id })
        #expect(user.context != nil)
        #expect(comment.context?.identifier == user.context?.identifier)
        
        try container.context.delete(user)
        
        let postDeleteComments = try container.context.fetchAll(
            CommentRelationshipCascade.Comment.self
        )
        #expect(postDeleteComments.isEmpty)
        
        try container.context.save()
        
        let postDeletePostSaveComments = try container.context.fetchAll(
            CommentRelationshipCascade.Comment.self
        )
        #expect(postDeletePostSaveComments.isEmpty)
        
        try verifyWithNewContainer()
        
        func verifyWithNewContainer() throws {
            let container = try ModelContainer(
                CommentRelationshipCascade.self,
                migration: CascadeMigration.self,
                at: dbPath,
                appID: "de.amethystsoft.vein.RelationshipTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            
            let comment = try container.context.fetchAll(CommentRelationshipCascade.Comment.self).first
            #expect(comment == nil)
        }
    }
    
    @Test(.timeLimit(.minutes(1)))
    func testDeleteCascadeCascade() async throws {
        let dbPath = try prepareContainerLocation(name: "DeleteCascadeCascade")
        
        Self.logger.info(
            "Relationship migration test started with db location: \(dbPath)"
        )
        
        let container = try ModelContainer(
            RelationshipCascadeCascade.self,
            migration: CascadeCascadeMigration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        let user = RelationshipCascadeCascade.User(name: "Mia")
        let comment = RelationshipCascadeCascade.Comment(text: "Heyho")
        try container.context.insert(user)
        user.comments.append(comment)
        
        try container.context.save()
        
        #expect(user.comments.contains { $0.id == comment.id })
        #expect(user.context != nil)
        #expect(comment.context?.identifier == user.context?.identifier)
        
        try container.context.delete(user)
        
        let postDeleteComments = try container.context.fetchAll(
            RelationshipCascadeCascade.Comment.self
        )
        #expect(postDeleteComments.isEmpty)
        
        try container.context.save()
        
        let postDeletePostSaveComments = try container.context.fetchAll(
            RelationshipCascadeCascade.Comment.self
        )
        #expect(postDeletePostSaveComments.isEmpty)
        
        try verifyWithNewContainer()
        
        func verifyWithNewContainer() throws {
            let container = try ModelContainer(
                RelationshipCascadeCascade.self,
                migration: CascadeCascadeMigration.self,
                at: dbPath,
                appID: "de.amethystsoft.vein.RelationshipTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            
            let comment = try container.context.fetchAll(RelationshipCascadeCascade.Comment.self).first
            #expect(comment == nil)
        }
    }
    
    @Test(.timeLimit(.minutes(1)))
    func testDeleteNullify() async throws {
        let dbPath = try prepareContainerLocation(name: "DeleteNullify")
        
        Self.logger.info(
            "Relationship migration test started with db location: \(dbPath)"
        )
        
        let container = try ModelContainer(
            CommentRelationshipNullify.self,
            migration: NullifyMigration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        let user = CommentRelationshipNullify.User(name: "Mia")
        let comment = CommentRelationshipNullify.Comment(text: "Heyho")
        try container.context.insert(user)
        user.comments.append(comment)
        
        try container.context.save()
        
        #expect(user.comments.contains { $0.id == comment.id })
        #expect(user.context != nil)
        #expect(comment.context?.identifier == user.context?.identifier)
        
        try container.context.delete(user)
        
        let postDeleteUsers = try container.context.fetchAll(
            CommentRelationshipNullify.User.self
        )
        #expect(postDeleteUsers.isEmpty)
        
        let postDeleteComments = try container.context.fetchAll(
            CommentRelationshipNullify.Comment.self
        )
        #expect(postDeleteComments.map(\.id) == [comment.id])
        #expect(postDeleteComments.map(\.author?.id) == [nil])
        
        try container.context.save()
        
        let postDeletePostSaveUsers = try container.context.fetchAll(
            CommentRelationshipNullify.User.self
        )
        #expect(postDeletePostSaveUsers.isEmpty)
        
        let postDeletePostSaveComments = try container.context.fetchAll(
            CommentRelationshipNullify.Comment.self
        )
        #expect(postDeletePostSaveComments.map(\.id) == [comment.id])
        #expect(postDeletePostSaveComments.map(\.author?.id) == [nil])
        
        try verifyWithNewContainer()
        
        func verifyWithNewContainer() throws {
            let container = try ModelContainer(
                CommentRelationshipNullify.self,
                migration: NullifyMigration.self,
                at: dbPath,
                appID: "de.amethystsoft.vein.RelationshipTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            
            let users = try container.context.fetchAll(
                CommentRelationshipNullify.User.self
            )
            #expect(users.isEmpty)
            
            let comments = try container.context.fetchAll(
                CommentRelationshipNullify.Comment.self
            )
            #expect(comments.map(\.id) == [comment.id])
            #expect(comments.map(\.author?.id) == [nil])
        }
    }
}

fileprivate enum CommentRelationshipCascade: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self, Comment.self]
    
    @Model
    final class User: Identifiable {
        @Field
        var name: String
        
        @Relationship(inverse: \Comment.author, deleteRule: .cascade)
        var comments: [Comment]
        
        init(name: String) {
            self.name = name
        }
        
        func commentIDs() -> [ULID] {
            _comments.idStore
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
}

fileprivate enum CascadeMigration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [CommentRelationshipCascade.self]
    }
    
    static var stages: [MigrationStage] {[]}
}

fileprivate enum RelationshipCascadeCascade: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self, Comment.self]
    
    @Model
    final class User: Identifiable {
        @Field
        var name: String
        
        @Relationship(deleteRule: .cascade)
        var comments: [Comment]
        
        init(name: String) {
            self.name = name
        }
        
        func commentIDs() -> [ULID] {
            _comments.idStore
        }
    }
    
    @Model
    final class Comment: Identifiable {
        @Relationship(inverse: \User.comments, deleteRule: .cascade)
        var author: User?
        
        @Field
        var text: String
        
        init(text: String) {
            self.text = text
        }
    }
}

fileprivate enum CascadeCascadeMigration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [RelationshipCascadeCascade.self]
    }
    
    static var stages: [MigrationStage] {[]}
}

fileprivate enum CommentRelationshipNullify: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self, Comment.self]
    
    @Model
    final class User: Identifiable {
        @Field
        var name: String
        
        @Relationship(inverse: \Comment.author)
        var comments: [Comment]
        
        init(name: String) {
            self.name = name
        }
        
        func commentIDs() -> [ULID] {
            _comments.idStore
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
}

fileprivate enum NullifyMigration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [CommentRelationshipNullify.self]
    }
    
    static var stages: [MigrationStage] {[]}
}
