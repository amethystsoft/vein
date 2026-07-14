import Foundation
import Testing
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct EncryptionTest {
    func prepareContainerLocation(name: String) throws -> String {
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
    
    @Test
    func testEncryption() async throws {
        let path = try prepareContainerLocation(name: "encryptionTest")
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: path,
            appID: "de.amethystsoft.vein.tests.encryption"
        )
        
        let model = V0_0_1.Test(someValue: "test")
        try container.context.insert(model)
        try container.context.save()
        
        let newContainer = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: path,
            appID: "de.amethystsoft.vein.tests.encryption"
        )
        
        let first = try newContainer.context.fetchAll(V0_0_1.Test.self).first
        
        #expect(first?.someValue == "test")
        
        do {
            let unencryptedContainer = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: path,
                appID: "de.amethystsoft.vein.tests.encryption",
                encryptionEnabled: false
            )
            
            let results = try unencryptedContainer.context.fetchAll(V0_0_1.Test.self)
            Issue.record("Didn't throw an error, db might not be encrypted")
        } catch {
            if case .notADatabase = error { return }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        }
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test: Identifiable {
        var someValue: String
        
        @LazyField
        var text: String?
        
        init(someValue: String) {
            self.someValue = someValue
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {
        []
    }
}
