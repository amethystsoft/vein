import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

extension MigrationTests {
    @Test
    func simpleMigration() throws {
        let dbPath = try prepareContainerLocation(name: "simpleMigration")
        
        logger.info(
            "Simple migration test started with db location: \(dbPath)"
        )
        
        let container = try ModelContainer(models: SimpleSchemaV0_0_1.models, migration: SimpleMigrationSuccess.self, at: dbPath)
        
        let test = SimpleSchemaV0_0_1.Test(date: Date())
        let unused = SimpleSchemaV0_0_1.Unused(content: "whoppa")
        
        try container.context.insert(test)
        try container.context.insert(unused)
        
        // Check both tables exist under the expected name
        let storedSchemas = try container.context.getAllStoredSchemas()
        #expect(
            storedSchemas.sorted() == [
                SimpleSchemaV0_0_1.Test.schema,
                SimpleSchemaV0_0_1.Unused.schema
            ].sorted()
        )
        
        // Create new container & trigger migration
        let newContainer = try ModelContainer(models: SimpleSchemaV0_0_2.models, migration: SimpleMigrationSuccess.self, at: dbPath)
        try newContainer.migrate()
        
        // Check new model was migrated correctly
        let first = try newContainer.context.fetchAll(SimpleSchemaV0_0_2.Test._PredicateHelper()._builder()).first
        
        #expect(first?.date == test.date.ISO8601Format(Date.sqliteFormatStyle))
        
        // Check if tables got updated/deleted like expected
        let newStoredSchemas = try newContainer.context.getAllStoredSchemas()
        #expect(newStoredSchemas == [SimpleSchemaV0_0_2.Test.schema])
    }
    
    @Test
    func unchangedFailsOutsideMigration() throws {
        let dbPath = try prepareContainerLocation(name: "tableDeletion")
        let container = try ModelContainer(models: SimpleSchemaV0_0_1.models, migration: SimpleMigrationSuccess.self, at: dbPath)
        
        
        do {
            try SimpleSchemaV0_0_1.Test
                .unchangedMigration(
                    to: SimpleSchemaV0_0_2.Test.self,
                    on: container.context
                )
        } catch let error as ManagedObjectContextError {
            if case let .notInsideMigration(function) = error {
                #expect(function == "PersistentModel/unchangedMigration")
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
        }
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test
    func deleteFailsOutsideMigration() throws {
        let dbPath = try prepareContainerLocation(name: "tableDeletion")
        let container = try ModelContainer(models: SimpleSchemaV0_0_1.models, migration: SimpleMigrationSuccess.self, at: dbPath)

        do {
            try SimpleSchemaV0_0_1.Test
                .deleteMigration(on: container.context)
        } catch let error as ManagedObjectContextError {
            if case let .notInsideMigration(function) = error {
                #expect(function == "PersistentModel/deleteMigration")
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
        }
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test
    func versionOrderThrowsOnUnchangedMigration() throws {
        let dbPath = try prepareContainerLocation(name: "tableDeletion")
        let container = try ModelContainer(models: SimpleSchemaV0_0_1.models, migration: SimpleMigrationSuccess.self, at: dbPath)
        
        // Entering migration manually
        // This is an internal function and not publicly exposed
        container.context.isInActiveMigration = true
        
        do {
            try SimpleSchemaV0_0_2.Test
                .unchangedMigration(
                    to: SimpleSchemaV0_0_1.Test.self,
                    on: container.context
                )
        } catch let error as ManagedObjectContextError {
            if
                case let .baseNotOlderThanDestination(
                    base,
                    destination
                ) = error
            {
                // Comparing schema because `Testing`
                // seems to have a problem with it
                #expect(base.schema == SimpleSchemaV0_0_2.Test.schema)
                #expect(destination.schema == SimpleSchemaV0_0_1.Test.schema)
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
        }
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test
    func equalVersionThrowsOnUnchangedMigration() throws {
        let dbPath = try prepareContainerLocation(name: "tableDeletion")
        let container = try ModelContainer(models: SimpleSchemaV0_0_1.models, migration: SimpleMigrationSuccess.self, at: dbPath)
        
        // Entering migration manually
        // This is an internal function and not publicly exposed
        container.context.isInActiveMigration = true
        
        do {
            try SimpleSchemaV0_0_2.Test
                .unchangedMigration(
                    to: SimpleSchemaV0_0_2.Test.self,
                    on: container.context
                )
        } catch let error as ManagedObjectContextError {
            if
                case let .baseNotOlderThanDestination(
                    base,
                    destination
                ) = error
            {
                // Comparing schema because `Testing`
                // seems to have a problem with it
                #expect(base.schema == SimpleSchemaV0_0_2.Test.schema)
                #expect(destination.schema == SimpleSchemaV0_0_2.Test.schema)
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
        }
        Issue.record("Unexpectedly no error was thrown")
    }
}

fileprivate enum SimpleSchemaV0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    
    static let models: [any Vein.PersistentModel.Type] = [
        Test.self,
        Unused.self
    ]
    
    @Model
    final class Test: Identifiable {
        @Field
        var date: Date
        
        init(date: Date) {
            self.date = date
        }
    }
    
    @Model
    final class Unused {
        @Field
        var content: String
        
        init(content: String) {
            self.content = content
        }
    }
}

fileprivate enum SimpleSchemaV0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 2)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test: Identifiable {
        @Field
        var date: String
        
        init(date: String) {
            self.date = date
        }
    }
}

fileprivate enum SimpleMigrationSuccess: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [SimpleSchemaV0_0_1.self, SimpleSchemaV0_0_2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.complex(
        fromVersion: SimpleSchemaV0_0_1.self,
        toVersion: SimpleSchemaV0_0_2.self,
        willMigrate: { context in
            try SimpleSchemaV0_0_1.Test.unchangedMigration(
                to: SimpleSchemaV0_0_2.Test.self,
                on: context
            )
            
            try SimpleSchemaV0_0_1.Unused.deleteMigration(on: context)
        },
        didMigrate: nil
    )
}

