import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

extension MigrationTests {
    @Test func throwsEmptySchemaMigrationPlanOnEmptySchemaMigrationPlan() async throws {
        let path = try prepareContainerLocation(name: "determineSchemaVersion")
        let container = try ModelContainer(
            models: [],
            migration: MigrationPlan.self,
            at: path
        )
        do {
            try container.migrate()
        } catch let error as ManagedObjectContextError {
            if case let .emptySchemaMigrationPlan(migration) = error {
                #expect("\(migration)" == "\(MigrationPlan.self)")
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

fileprivate enum MigrationPlan: SchemaMigrationPlan {
    static var stages: [Vein.MigrationStage] {
        []
    }
    
    static var schemas: [any Vein.VersionedSchema.Type] {
        []
    }
    
}
