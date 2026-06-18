import Foundation
import Testing
@testable import VeinTesting
import Vein
import VeinCore

struct MultithreadedTest {
    @Test
    func run() async throws {
        let container = try ModelContainer(
            Version1.self,
            migration: MigrationPlan.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let model = Version1.Task(name: "Task \(i)")
                    try! container.context.insert(model)
                    try! container.context.save()
                    
                    _ = try! container.context.fetchAll(Version1.Task.self)
                }
            }
        }
        
        let total = try! container.context.fetchAll(Version1.Task.self).count
        #expect(total == 100)
    }
}

fileprivate enum Version1: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        Task.self
    ]}
    
    @Model
    final class Task {
        @Field var name: String
        init(name: String) { self.name = name }
    }
}

fileprivate enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self
    ]}
    
    static var stages: [Vein.MigrationStage] {[]}
}

