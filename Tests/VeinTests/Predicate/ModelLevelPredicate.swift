import Foundation
import Testing
import Logging
import SQLiteDB
@testable import Vein
@testable import VeinCore

@Suite
struct PredicateConversionTests {
    @Test
    func fieldComparison() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email == user.name
        }
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ("email" = "name")
        """)
    }
    
    @Test
    func singleCondition() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email == "test@example.com"
        }
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ("email" = ?)
        """)
        
        guard
            query.expression.bindings.count == 2,
            let boundEmail = query.expression.bindings[1] as? String
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundEmail == "test@example.com")
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self]
    
    @Model
    final class User: Identifiable {
        @Field
        var name: String
        
        @Field
        var email: String
        
        @Field
        var birthday: Date
        
        @Field
        var balance: Double
        
        init(name: String, email: String, birthday: Date) {
            self.name = name
            self.email = email
            self.birthday = birthday
            self.balance = 0
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {[]}
}
