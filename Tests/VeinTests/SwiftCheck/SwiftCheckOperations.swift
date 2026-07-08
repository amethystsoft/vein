#if canImport(SwiftCheck)
    import SwiftCheck
    import Foundation
    import XCTest
    @testable import Vein
    #if TEST_SWIFTUI
        @_spi(VeinTesting) @testable import VeinSwiftUI
    #elseif !TEST_SWIFTUI
        @_spi(VeinTesting) @testable import VeinCore
    #endif

    fileprivate typealias Test = V0_0_1.Test
    final class SwiftCheckOperationsSuite: XCTestCase {
        func testRandomOperations() {
            property("State matches local reference after random operations") <-
                forAll { (ops: [DatabaseOp]) in
                    let appID = "de.amethystsoft.vein.tests.RandomOps"

                    var referenceArray = [TestSnapshot]()

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for op in ops {
                        switch op {
                            case .insert(let test):
                                referenceArray.append(TestSnapshot(
                                    id: test.id,
                                    someValue: test.someValue,
                                    text: test.text
                                ))
                                try container.context.insert(test)

                            case .delete(let index):
                                guard !referenceArray.isEmpty else { break }
                                let idx = abs(index) % referenceArray.count
                                let toDeleteSnapshot = referenceArray.remove(at: idx)

                                let id = toDeleteSnapshot.id
                                let predicate = #Predicate<V0_0_1.Test> { $0.id == id }
                                if let object = try container.context.fetchAll(predicate).first {
                                    try container.context.delete(object)
                                }

                            case .update(let index, let newVal):
                                guard !referenceArray.isEmpty else { break }
                                let idx = abs(index) % referenceArray.count

                                let old = referenceArray[idx]
                                referenceArray[idx] = TestSnapshot(
                                    id: old.id,
                                    someValue: newVal,
                                    text: old.text
                                )

                                let id = old.id
                                let predicate = #Predicate<V0_0_1.Test> { $0.id == id }
                                if let object = try container.context.fetchAll(predicate).first {
                                    object.someValue = newVal
                                }
                        }
                    }

                    try container.context.save()

                    // Verification using a fresh context to ensure changes are read from db
                    let verificationContainer = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        connection: container.getConnection(),
                        appID: appID,
                        encryptionEnabled: false
                    )

                    let fetchedModels = try verificationContainer.context.fetchAll(V0_0_1.Test.self)

                    // Compare Snapshots to Fetched Models
                    let countsMatch = fetchedModels.count == referenceArray.count

                    let sortedRef = referenceArray.sorted { $0.id < $1.id }
                    let sortedFetched = fetchedModels.sorted { $0.id < $1.id }

                    let contentsMatch = zip(sortedRef, sortedFetched)
                        .allSatisfy { snapshot, fetched in
                            snapshot.someValue == fetched.someValue &&
                                snapshot.text == fetched.text
                        }

                    return countsMatch && contentsMatch
                }
        }
    }

    struct TestSnapshot: Equatable {
        let id: ULID
        let someValue: String
        let text: String?
    }

    fileprivate enum V0_0_1: VersionedSchema {
        static let version = ModelVersion(0, 0, 1)
        static let models: [any Vein.PersistentModel.Type] = [Test.self]

        @Model
        final class Test: Identifiable {
            var someValue: String

            @LazyField
            var text: String?

            init(someValue: String, text: String?) {
                self.someValue = someValue
                self.text = text
            }

            func getLazyField() -> LazyField<String> {
                _text
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

    extension V0_0_1.Test: Arbitrary {
        static fileprivate var arbitrary: SwiftCheck.Gen<Test> {
            return Gen<Test>.compose { dg in
                Test(
                    someValue: dg.generate(),
                    text: dg.generate()
                )
            }
        }
    }

    fileprivate enum DatabaseOp: CustomStringConvertible {
        case insert(V0_0_1.Test)
        case delete(Int) // Delete at index
        case update(Int, String) // Update index with new string

        var description: String {
            switch self {
                case .insert: return "Insert"
                case .delete(let i): return "Delete at \(i)"
                case .update(let i, _): return "Update at \(i)"
            }
        }
    }

    extension DatabaseOp: Arbitrary {
        fileprivate static var arbitrary: Gen<DatabaseOp> {
            return Gen<DatabaseOp>.one(of: [
                V0_0_1.Test.arbitrary.map(DatabaseOp.insert),
                Gen<Int>.choose((0, 100)).map(DatabaseOp.delete),
                Gen<(Int, String)>.compose { dg in
                    (dg.generate(using: Gen.choose((0, 100))), dg.generate())
                }.map(DatabaseOp.update)
            ])
        }
    }

#endif
