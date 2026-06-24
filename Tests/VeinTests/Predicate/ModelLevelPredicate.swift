import Foundation
import Testing
import Logging
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
@testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
@testable import VeinCore
#endif

@Suite
struct PredicateConversionTests {
    @Test
    func fieldEqualsField() async throws {
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
    func fieldEqualsValue() async throws {
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
    
    @Test
    func valueEqualsField() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            "test@example.com" == user.email
        }
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE (? = "email")
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
    
    @Test
    func fieldDoesntEqualField() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email != user.name
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ("email" != "name")
        """)
    }
    
    @Test
    func fieldDoesntEqualValue() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email != "test@example.com"
        }
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ("email" != ?)
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
    
    @Test
    func stringFieldContainsValue() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email.contains("test")
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE instr("email", ?) > 0
        """)
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? String
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundFilter == "test")
    }
    
    @Test
    func stringContainsField() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email.contains(user.name)
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE instr("email", "name") > 0
        """)
        
        #expect(query.expression.bindings.count == 1)
    }
    
    @Test
    func doubleFieldBiggerThanDouble() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.balance > 42069.0
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ("balance" > ?)
        """)
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? Double
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundFilter == 42069.0)
    }
    
    @Test
    func doubleFieldLessThanOrEqual() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.balance <= 1234.56
        }
        
        let expression = try predicate.toSQLiteFilter()
        let query = Table("users").filter(expression).select(["*"])
        
        #expect(
            query.expression.template == """
        SELECT ? FROM "users" WHERE ("balance" <= ?)
        """
        )
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? Double
        else {
            Issue.record("Failed to extract Double binding")
            return
        }
        #expect(boundFilter == 1234.56)
    }
    
    @Test
    func doubleFieldGreaterThan() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.balance > 0.0
        }
        
        let expression = try predicate.toSQLiteFilter()
        let query = Table("users").filter(expression).select(["*"])
        
        #expect(
            query.expression.template == """
        SELECT ? FROM "users" WHERE ("balance" > ?)
        """
        )
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? Double
        else {
            Issue.record("Failed to extract Double binding")
            return
        }
        #expect(boundFilter == 0.0)
    }
    
    @Test
    func doubleFieldGreaterThanOrEqual() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.balance >= -10.5
        }
        
        let expression = try predicate.toSQLiteFilter()
        let query = Table("users").filter(expression).select(["*"])
        
        #expect(
            query.expression.template == """
        SELECT ? FROM "users" WHERE ("balance" >= (-?))
        """
        )
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? Double
        else {
            Issue.record("Failed to extract Double binding")
            return
        }
        #expect(boundFilter == 10.5)
    }
    
    @Test
    func doubleFieldGreaterThanDoubleField() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.balance > user.pendingTransactionValue
        }
        
        let expression = try predicate.toSQLiteFilter()
        let query = Table("users").filter(expression).select(["*"])
        
        #expect(
            query.expression.template == """
        SELECT ? FROM "users" WHERE ("balance" > "pendingTransactionValue")
        """
        )
        #expect(query.expression.bindings.count == 1)
    }
    
    @Test
    func doubleFieldLessThanOrEqualToDoubleField() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.balance <= user.pendingTransactionValue
        }
        
        let expression = try predicate.toSQLiteFilter()
        let query = Table("users").filter(expression).select(["*"])
        
        #expect(
            query.expression.template == """
        SELECT ? FROM "users" WHERE ("balance" <= "pendingTransactionValue")
        """
        )
        #expect(query.expression.bindings.count == 1)
    }
    
    @Test
    func doubleFieldGreaterThanOrEqualToDoubleField() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.balance >= -user.pendingTransactionValue
        }
        
        let expression = try predicate.toSQLiteFilter()
        let query = Table("users").filter(expression).select(["*"])
        
        #expect(
            query.expression.template == """
        SELECT ? FROM "users" WHERE ("balance" >= (-"pendingTransactionValue"))
        """
        )
        #expect(query.expression.bindings.count == 1)
    }
    
    @Test
    func and() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email == user.name && user.balance > 2
        }
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE (("email" = "name") AND ("balance" > ?))
        """)
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? Double
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundFilter == 2)
    }
    
    @Test
    func or() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email == user.name || user.balance > 2
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE (("email" = "name") OR ("balance" > ?))
        """)
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? Double
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundFilter == 2)
    }
    
    @Test
    func not() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            !(user.email == user.name || user.balance > 2)
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ((("email" = "name") OR ("balance" > ?)) = ?)
        """)
        
        guard
            query.expression.bindings.count == 3,
            let boundFilter = query.expression.bindings[1] as? Double,
            let notBool = query.expression.bindings[2] as? Int64
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundFilter == 2)
        #expect(notBool == 0)
    }
    
    @Test
    func isNil() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.somethingOptional == nil
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ("somethingOptional" IS NULL)
        """)
    }
    
    @Test
    func isNotNil() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.somethingOptional != nil
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE ("somethingOptional" IS NOT NULL)
        """)
    }
    
    @Test
    func startsWithString() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.name.starts(with: "Mia")
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE instr("name", ?) = 1
        """)
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? String
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundFilter == "Mia")
    }
    
    @Test
    func startsWithField() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.email.starts(with: user.name)
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE instr("email", "name") = 1
        """)
        
        #expect(query.expression.bindings.count == 1)
    }
    
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @Test
    func caseInsensitiveFieldContainsString() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.name.localizedStandardContains("Mia")
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE instr(lower("name"), ?) > 0
        """)
        
        guard
            query.expression.bindings.count == 2,
            let boundFilter = query.expression.bindings[1] as? String
        else {
            Issue.record("Failed in getting correct bindings")
            return
        }
        #expect(boundFilter == "mia")
    }
    
    @Test
    func caseInsensitiveFieldContainsField() async throws {
        let predicate = #Predicate<V0_0_1.User> { user in
            user.name.localizedStandardContains(user.email)
        }
        
        let expression = try predicate.toSQLiteFilter()
        let filter = Table("users").filter(expression)
        let query = filter.select(["*"])
        
        #expect(query.expression.template == """
        SELECT ? FROM "users" WHERE instr(lower("name"), lower("email")) > 0
        """)
        #expect(query.expression.bindings.count == 1)
    }
#endif
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
        
        @Field
        var pendingTransactionValue: Double
        
        @Field
        var somethingOptional: String?
        
        init(name: String, email: String, birthday: Date) {
            self.name = name
            self.email = email
            self.birthday = birthday
            self.balance = 0
            self.pendingTransactionValue = 0
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {[]}
}
