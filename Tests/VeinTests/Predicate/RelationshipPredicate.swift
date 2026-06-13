import Foundation
import Testing
import Logging
import SQLiteDB
@testable import Vein
@testable import VeinCore

extension PredicateConversionTests {
    @Test(.disabled())
    func relationshipPredicate() async throws {
        let ulid = ULID()
        let predicate = #Predicate<V0_0_1.Comment> { comment in
            comment.author?.name == "Mia"
        }
        print(predicate.expression)
        
        let expression = try predicate.toSQLiteFilter()
        
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ("id" = ?)
        """)
        
        guard
            query.expression.bindings.count == 2,
            let boundEmail = query.expression.bindings[1] as? String
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundEmail == ulid.ulidString)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
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

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {[]}
}
