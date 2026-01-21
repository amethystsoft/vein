import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

extension MigrationTests {
    @Test
    func fieldsAddedMigration() throws {
        let dbPath = try prepareContainerLocation(name: "fieldAddedMigration")
        
        logger.info(
            "Field added migration test started with db location: \(dbPath)"
        )
        
        let container = try ModelContainer(models: SimpleSchemaV0_0_3.models, migration: SimpleMigration.self, at: dbPath)
        
        let test = SimpleSchemaV0_0_3.AddingFieldsModel(value: "")
        
        try container.context.insert(test)
        
        // Check both tables exist under the expected name
        let storedSchemas = try container.context.getAllStoredSchemas()
        #expect(
            storedSchemas.sorted() == [
                SimpleSchemaV0_0_3.AddingFieldsModel.schema
            ].sorted()
        )
        
        // Create new container & trigger migration
        let newContainer = try ModelContainer(models: SimpleSchemaV0_0_4.models, migration: SimpleMigration.self, at: dbPath)
        try newContainer.migrate()
        
        // Check new model was migrated correctly
        let first = try newContainer.context.fetchAll(
            SimpleSchemaV0_0_4.AddingFieldsModel._PredicateHelper()._builder()
        ).first
        
        #expect(first?.newValue == nil)
        #expect(first?.value == test.value)
        
        // Check if tables got updated/deleted like expected
        let newStoredSchemas = try newContainer.context.getAllStoredSchemas()
        #expect(newStoredSchemas == [SimpleSchemaV0_0_4.AddingFieldsModel.schema])
    }
    
    @Test
    func versionOrderThrowsOnFieldsAddedMigration() throws {
        let dbPath = try prepareContainerLocation(name: "errorTests")
        let container = try ModelContainer(models: SimpleSchemaV0_0_1.models, migration: SimpleMigration.self, at: dbPath)
        
        // Entering migration manually
        // This is an internal function and not publicly exposed
        container.context.isInActiveMigration = true
        
        do {
            try SimpleSchemaV0_0_2.Test
                .fieldsAddedMigration(
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
                #expect(base.schema == SimpleSchemaV0_0_2.Test.schema)
                #expect(destination.schema == SimpleSchemaV0_0_1.Test.schema)
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
            return
        }
        
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test
    func equalVersionThrowsOnFieldsAddedMigration() throws {
        let dbPath = try prepareContainerLocation(name: "errorTests")
        let container = try ModelContainer(models: SimpleSchemaV0_0_1.models, migration: SimpleMigration.self, at: dbPath)
        
        // Entering migration manually
        // This is an internal function and not publicly exposed
        container.context.isInActiveMigration = true
        
        do {
            try SimpleSchemaV0_0_2.Test
                .fieldsAddedMigration(
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
                #expect(base.schema == SimpleSchemaV0_0_2.Test.schema)
                #expect(destination.schema == SimpleSchemaV0_0_2.Test.schema)
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
            return
        }
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test
    func destinationMustHaveOnlyAddedFieldsOnFieldsAddedMigration() throws {
        let dbPath = try prepareContainerLocation(name: "errorTests")
        let container = try ModelContainer(models: SimpleSchemaV0_0_3.models, migration: SimpleMigration.self, at: dbPath)
        
        // Entering migration manually
        // This is an internal function and not publicly exposed
        container.context.isInActiveMigration = true
        
        do {
            try SimpleSchemaV0_0_3.AddingFieldsModel
                .fieldsAddedMigration(
                    to: SimpleSchemaV0_0_6.AddingFieldsModel.self,
                    on: container.context
                )
        } catch let error as ManagedObjectContextError {
            if
                case let .destinationMustHaveOnlyAddedFields(
                    base,
                    destination
                ) = error
            {
                #expect(base.schema == SimpleSchemaV0_0_3.AddingFieldsModel.schema)
                #expect(destination.schema == SimpleSchemaV0_0_6.AddingFieldsModel.schema)
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
            return
        }
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test
    func requiresOnlyOptionalFieldsAddedOnFieldsAddedMigration() throws {
        let dbPath = try prepareContainerLocation(name: "errorTests")
        let container = try ModelContainer(models: SimpleSchemaV0_0_3.models, migration: SimpleMigration.self, at: dbPath)
        
        // Entering migration manually
        // This is an internal function and not publicly exposed
        container.context.isInActiveMigration = true
        
        do {
            try SimpleSchemaV0_0_3.AddingFieldsModel
                .fieldsAddedMigration(
                    to: SimpleSchemaV0_0_5.AddingFieldsModel.self,
                    on: container.context
                )
        } catch let error as ManagedObjectContextError {
            if
                case let .automaticMigrationRequiresOnlyOptionalFieldsAdded(
                    base,
                    destination
                ) = error
            {
                #expect(base.schema == SimpleSchemaV0_0_3.AddingFieldsModel.schema)
                #expect(destination.schema == SimpleSchemaV0_0_5.AddingFieldsModel.schema)
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
            return
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

fileprivate enum SimpleSchemaV0_0_3: VersionedSchema {
    static let version = ModelVersion(0, 0, 3)
    static let models: [any Vein.PersistentModel.Type] = [
        Test.self,
        AddingFieldsModel.self
    ]
    
    // Used to test field mismatch on changing underlying SQLite type
    @Model
    final class Test: Identifiable {
        @Field
        var date: Int
        
        @Field
        var additionalField: Int?
        
        init(date: Int) {
            self.date = date
        }
    }
    
    @Model
    final class AddingFieldsModel {
        @Field
        var value: String
        
        init(value: String) {
            self.value = value
        }
    }
}

fileprivate enum SimpleSchemaV0_0_4: VersionedSchema {
    static let version = ModelVersion(0, 0, 4)
    static let models: [any Vein.PersistentModel.Type] = [
        Test.self,
        AddingFieldsModel.self
    ]
    
    // Used to test field mismatch on changing field name with consistent field type
    @Model
    final class Test: Identifiable {
        @Field
        var addedAt: Date
        
        @Field
        var additionalField: Int?
        
        init(addedAt: Date) {
            self.addedAt = addedAt
        }
    }
    
    @Model
    final class AddingFieldsModel {
        @Field
        var value: String
        
        @Field
        var newValue: String?
        
        init(value: String) {
            self.value = value
        }
    }
}

fileprivate enum SimpleSchemaV0_0_5: VersionedSchema {
    static let version = ModelVersion(0, 0, 5)
    static let models: [any Vein.PersistentModel.Type] = [
        Test.self,
        AddingFieldsModel.self
    ]
    
    // Used to test field mismatch on changing field name with consistent field type
    @Model
    final class Test: Identifiable {
        @Field
        var date: Date
        
        init(date: Date) {
            self.date = date
        }
    }
    
    // Used to test throwing automaticMigrationRequiresOnlyOptionalFieldsAdded
    // on fieldsAddedMigration
    @Model
    final class AddingFieldsModel {
        @Field
        var value: String
        
        @Field
        var newValue: String
        
        init(value: String, newValue: String) {
            self.value = value
            self.newValue = newValue
        }
    }
}

fileprivate enum SimpleSchemaV0_0_6: VersionedSchema {
    static let version = ModelVersion(0, 0, 6)
    static let models: [any Vein.PersistentModel.Type] = [
        Test.self,
        AddingFieldsModel.self
    ]
    
    // Used to test field mismatch on changing field name with consistent field type
    @Model
    final class Test: Identifiable {
        @Field
        var addedAt: Date
        
        @Field
        var additionalField: Int?
        
        init(addedAt: Date) {
            self.addedAt = addedAt
        }
    }
    
    @Model
    final class AddingFieldsModel {
        @Field
        var eulav: String
        
        @Field
        var newValue: String?
        
        init(eulav: String) {
            self.eulav = eulav
        }
    }
}

fileprivate enum SimpleMigration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [
            SimpleSchemaV0_0_1.self,
            SimpleSchemaV0_0_2.self,
            SimpleSchemaV0_0_3.self,
            SimpleSchemaV0_0_4.self,
        ]
    }
    
    static var stages: [MigrationStage] {
        [
            migrateV1toV2,
            migrateV3toV4
        ]
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
    
    static let migrateV3toV4 = MigrationStage.complex(
        fromVersion: SimpleSchemaV0_0_3.self,
        toVersion: SimpleSchemaV0_0_4.self,
        willMigrate: { context in
            try SimpleSchemaV0_0_3
                .AddingFieldsModel
                .fieldsAddedMigration(
                    to: SimpleSchemaV0_0_4.AddingFieldsModel.self,
                    on: context
                )
            
            let models = try context.fetchAll(
                SimpleSchemaV0_0_3.Test._PredicateHelper()._builder()
            )
            
            for model in models {
                let new = SimpleSchemaV0_0_4.Test(
                    addedAt: Date(timeIntervalSince1970: Double(model.date))
                )
                new.additionalField = model.additionalField
                
                try context.delete(model)
                try context.insert(new)
            }
            
            try context.cleanupOldSchema(SimpleSchemaV0_0_3.self)
        },
        didMigrate: nil
    )
}

