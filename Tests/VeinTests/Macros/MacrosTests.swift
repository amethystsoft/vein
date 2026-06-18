import Testing
import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import VeinCoreMacros

fileprivate let testMacros: [String: MacroSpec] = [
    "Model": MacroSpec(type: ModelMacro.self)
]

@Suite
struct MacrosTests {
    @Test
    func commentsAreNotTreatedAsPartOfType() async throws {
        assertMacroExpansion(
            """
            @Model
            final class Test {
                @Field
                var test: String // Test
            }
            """,
            expandedSource: """
            final class Test {
                @Field
                var test: String // Test
            
                /// The primary ID of the object.
                /// Gets  used to reference models in relationships.
                /// Immutable after insertion into the context.
                @Vein.PrimaryKey
                var id: Vein.ULID
            
                required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                    self.id = id
                    self.test = try! String.init(
                        fromPersistent: String.PersistentRepresentation.decode(
                            sqliteValue: fields["test"]!
                        )
                    )!
                    
                    _setupFields()
                }
            
                let _observers = Vein.Atomic([Vein.ULID: () -> Void]())
            
                /// Sets required properties for @Field values.
                /// Gets generated automatically by @Model.
                public func _setupFields() {
                    self._test.model = self
                    self._test.key = "test"
                    self._id.model = self
                }
            
                var context: Vein.ManagedObjectContext? = nil
            
                /// Whether a model is prepared to be deleted.
                ///
                /// Reading this variable is safe, but it should never be set outside of Vein.
                var _isPreparedForDeletion = false
            
                var _fields: [any Vein.FieldBase] {
                    [
                        self._id,
                        self._test
                    ]
                }
            
                var _relationships: [any Vein.PersistedRelationship] {
                    [
                        
                    ]
                }
            
                static let _inverseFields = {
                    var map = [ObjectIdentifier: [String: String]]()
                    
                    return map
                }()
            
                static func _predicateInformation(for keyPath: PartialKeyPath<Test>) -> Vein.FieldInformation? {
                    switch keyPath {
                        case \\.test: Vein.FieldInformation(String.sqliteTypeName, "test", true)
                        case \\.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                        default: nil
                    }
                }
            
                static let _fieldInformation: [Vein.FieldInformation] = [
                    Vein.FieldInformation(String.sqliteTypeName, "test", true)
                ]
            
                var notifyOfChanges: () -> Void {
                    return {
                    }
                }
            }
            
            extension Test: Vein.PersistentModel, @unchecked Sendable {
                static let schema = "Test"
                static var version: Vein.ModelVersion {
                    Test.version
                }
            }
            """,
            macroSpecs: testMacros,
            failureHandler: { spec in
                Issue.record("\(spec.message)")
            }
        )
    }
}

