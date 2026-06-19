import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

@Suite
struct RealDatabasePredicateTests {
    func prepareContainerLocation(name: String) throws -> String {
#if os(Linux)
        if ProcessInfo.shouldEnableEncryption {
            Keyring.appIdentifier.withLock { identifier in
                identifier = "de.amethystsoft.vein.tests"
            }
        }
#endif
        
        let containerPath = FileManager.default.temporaryDirectory
        
        let dbDir = containerPath.relativePath.appending("/veinTests/\(testID.uuidString)")
        
        let dbPath = dbDir.appending("/\(name).sqlite3")
        
        try FileManager.default.createDirectory(
            atPath: dbDir,
            withIntermediateDirectories: true
        )
        
        if !FileManager.default.fileExists(atPath: dbPath) {
            FileManager.default.createFile(
                atPath: dbPath,
                contents: nil
            )
        }
        
        return dbPath
    }
    
    private func makeContainer(name: String) throws -> ModelContainer {
        let dbPath = try prepareContainerLocation(name: name)
        try makeTestData(name: name)
        
        return try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RealDatabasePredicateTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
    }
    
    // Helper to spin up a container and seed test users
    private func makeTestData(name: String) throws {
        let dbPath = try prepareContainerLocation(name: name)
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RealDatabasePredicateTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        // Seed users
        let user1 = V0_0_1.User(name: "Mia", email: "mia@example.com", birthday: Date())
        user1.balance = 500.0
        user1.pendingTransactionValue = 50.0
        user1.somethingOptional = "has_value"
        
        // Name matches email exactly
        let user2 = V0_0_1.User(name: "matching", email: "matching", birthday: Date())
        user2.balance = -10.0
        user2.pendingTransactionValue = 100.0
        user2.somethingOptional = nil
        
        let user3 = V0_0_1.User(name: "Charlie", email: "charlie@mia.com", birthday: Date())
        user3.balance = 0.0
        user3.pendingTransactionValue = 0.0
        user3.somethingOptional = nil
        
        try container.context.insert(user1)
        try container.context.insert(user2)
        try container.context.insert(user3)
        try container.context.save()
    }
    
    @Test
    func testFieldEqualsField() async throws {
        let container = try makeContainer(name: "FieldEqualsField")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.email == user.name
        })
        
        #expect(results.count == 1)
        #expect(results.first?.name == "matching")
    }
    
    @Test
    func testFieldEqualsValue() async throws {
        let container = try makeContainer(name: "FieldEqualsValue")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.email == "mia@example.com"
        })
        
        #expect(results.count == 1)
        #expect(results.first?.name == "Mia")
    }
    
    @Test
    func testFieldDoesntEqualValue() async throws {
        let container = try makeContainer(name: "FieldDoesntEqualValue")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.email != "mia@example.com"
        })
        
        #expect(results.count == 2)
    }
    
    @Test
    func testStringFieldContainsValue() async throws {
        let container = try makeContainer(name: "StringFieldContainsValue")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.email.contains("example")
        })
        
        #expect(results.count == 1)
        #expect(results.first?.name == "Mia")
    }
    
    @Test
    func testDoubleFieldCompare() async throws {
        let container = try makeContainer(name: "DoubleFieldCompare")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.balance > 100.0
        })
        
        #expect(results.count == 1)
        #expect(results.first?.name == "Mia")
    }
    
    @Test
    func testNegativeDoubleFieldCompare() async throws {
        let container = try makeContainer(name: "NegativeDoubleFieldCompare")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.balance >= -10.0
        })
        
        #expect(results.count == 3)
    }
    
    @Test
    func testDoubleFieldGreaterThanOrEqualToDoubleField() async throws {
        let container = try makeContainer(name: "DoubleFieldGreaterThanOrEqualToDoubleField")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.balance >= -user.pendingTransactionValue
        })
        
        #expect(results.count == 3) // Mia (500 >= -50), Charlie (0 >= 0), matching (-10 >= -100)
    }
    
    @Test
    func testAnd() async throws {
        let container = try makeContainer(name: "And")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.balance > 10.0 && user.somethingOptional != nil
        })
        
        #expect(results.count == 1)
        #expect(results.first?.name == "Mia")
    }
    
    @Test
    func testIsNil() async throws {
        let container = try makeContainer(name: "IsNil")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.somethingOptional == nil
        })
        
        #expect(results.count == 2)
    }

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @Test
    func testCaseInsensitiveContains() async throws {
        let container = try makeContainer(name: "CaseInsensitiveContains")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.name.localizedStandardContains("mia")
        })
        
        #expect(results.count == 1)
        #expect(results.first?.name == "Mia")
    }
#endif
    
    @Test
    func testStartsWithString() async throws {
        let container = try makeContainer(name: "StartsWith")
        
        let results = try container.context.fetchAll(#Predicate<V0_0_1.User> { user in
            user.name.starts(with: "M")
        })
        
        #expect(results.count == 1)
        #expect(results.first?.name == "Mia")
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
    
    static var stages: [MigrationStage] { [] }
}
