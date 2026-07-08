import Combine
import VeinSwiftUI
import Foundation

typealias Test = TestSchemaV0_0_1.Test
typealias TestChild = TestSchemaV0_0_1.TestChild

enum TestSchemaV0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)

    static let models: [any Vein.PersistentModel.Type] = [
        Test.self,
        TestChild.self
    ]

    @Model
    final class Test: Identifiable {
        @Field
        var flag: Bool

        @LazyField
        var selectedGroup: Group?

        @Field
        var randomValue: Int

        @Relationship(inverse: \TestChild.parent, deleteRule: .cascade)
        var child: TestChild?

        init(flag: Bool, randomValue: Int) {
            self.flag = flag
            self.randomValue = randomValue
        }
    }

    @Model
    final class TestChild {
        @Relationship
        var parent: Test?

        @Field
        var value: Int

        init() {
            self.value = Int.random(in: 0...99)
        }
    }
}

enum TestMigration: SchemaMigrationPlan {
    static var stages: [MigrationStage] {
        []
    }

    static var schemas: [any Vein.VersionedSchema.Type] {
        [TestSchemaV0_0_1.self]
    }
}

nonisolated enum Group: String, RawRepresentablePersistable, CaseIterable {
    case football
    case soccer
    case baseball
}
