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

extension PredicateConversionTests {
    @Test
    func persistableUsable() async throws {
        let ulid = ULID()
        let predicate = #Predicate<V0_0_1.User> { user in
            user.id == ulid
        }

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
