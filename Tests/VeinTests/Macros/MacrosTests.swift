import Testing
import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
#if TEST_SWIFTUI
@testable import VeinSwiftUIMacros
#elseif !TEST_SWIFTUI
@testable import VeinCoreMacros
#endif

fileprivate let testMacros: [String: MacroSpec] = [
    "Model": MacroSpec(type: ModelMacro.self)
]

@Suite
struct MacrosTests {
    @Test
    func commentsAreNotTreatedAsPartOfType() async throws {
        #if !TEST_SWIFTUI
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
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _updatedAt: Foundation.Date?
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _clientID: String?
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _isDeleted: Bool? = false
            
                required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                    self.id = id
                    self.test = try! String.init(
                        fromPersistent: String.PersistentRepresentation.decode(
                            sqliteValue: fields["test"]!
                        )
                    )!
                    
                    _setupFields()
                }
            
                let _observers = Vein.Mutex(Vein.ReferenceCountedObservers())
            
                /// Sets required properties for @Field values.
                /// Gets generated automatically by @Model.
                public func _setupFields() {
                    self.__clientID.model = self
                    self.__clientID.key = "_clientID"
                    self.__isDeleted.model = self
                    self.__isDeleted.key = "_isDeleted"
                    self.__updatedAt.model = self
                    self.__updatedAt.key = "_updatedAt"
                    self._test.model = self
                    self._test.key = "test"
                    self._id.model = self
                }
            
                let _context = Vein.Mutex<Vein.ManagedObjectContext?>(nil)
            
                /// Whether a model is prepared to be deleted.
                ///
                /// Reading this variable is safe, but it should never be set outside of Vein.
                var _isPreparedForDeletion = false
            
                var _fields: [any Vein.FieldBase] {
                    [
                        self._id,
                        self.__clientID,
                        self.__isDeleted,
                        self.__updatedAt,
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
                        case \\._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                        case \\._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                        case \\._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                        case \\.test: Vein.FieldInformation(String.sqliteTypeName, "test", true)
                        case \\.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                        default: nil
                    }
                }
            
                static let _fieldInformation: [Vein.FieldInformation] = [
                    Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                    Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                    Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
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
        #else
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

                @Vein.LazyField(suppressUIUpdates: true)
                var _updatedAt: Foundation.Date?
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _clientID: String?
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _isDeleted: Bool? = false
            
                required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                    self.id = id
                    self.test = try! String.init(
                        fromPersistent: String.PersistentRepresentation.decode(
                            sqliteValue: fields["test"]!
                        )
                    )!
                    
                    _setupFields()
                }
            
                let _observers = Vein.Mutex(Vein.ReferenceCountedObservers())
            
                /// Sets required properties for @Field values.
                /// Gets generated automatically by @Model.
                public func _setupFields() {
                    self.__clientID.model = self
                    self.__clientID.key = "_clientID"
                    self.__isDeleted.model = self
                    self.__isDeleted.key = "_isDeleted"
                    self.__updatedAt.model = self
                    self.__updatedAt.key = "_updatedAt"
                    self._test.model = self
                    self._test.key = "test"
                    self._id.model = self
                }
            
                let _context = Vein.Mutex<Vein.ManagedObjectContext?>(nil)
            
                /// Whether a model is prepared to be deleted.
                ///
                /// Reading this variable is safe, but it should never be set outside of Vein.
                var _isPreparedForDeletion = false
            
                var _fields: [any Vein.FieldBase] {
                    [
                        self._id,
                        self.__clientID,
                        self.__isDeleted,
                        self.__updatedAt,
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
                        case \\._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                        case \\._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                        case \\._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                        case \\.test: Vein.FieldInformation(String.sqliteTypeName, "test", true)
                        case \\.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                        default: nil
                    }
                }
            
                static let _fieldInformation: [Vein.FieldInformation] = [
                    Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                    Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                    Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
                    Vein.FieldInformation(String.sqliteTypeName, "test", true)
                ]
            
                let objectWillChange = PassthroughSubject<Void, Never>()
            
                var notifyOfChanges: () -> Void {
                    { [weak self] in
                        guard let self else { return }
                        self._observers.value.notifyAll()
                        self.objectWillChange.send()
                    }
                }
            }
            
            extension Test: Vein.PersistentModel, @unchecked Sendable {
                static let schema = "Test"
                static var version: Vein.ModelVersion {
                    Test.version
                }
            }
            
            @MainActor
            extension Test: ObservableObject {
            }
            """,
            macroSpecs: testMacros,
            failureHandler: { spec in
                Issue.record("\(spec.message)")
            }
        )
        #endif
    }
    
    @Test
    func fieldAutogenerationWorks() async throws {
        #if !TEST_SWIFTUI
        assertMacroExpansion(
            """
            @Model
            final class Test {
                var test: String // Test
            }
            """,
            expandedSource: """
            final class Test {
                @Vein.Field
                var test: String // Test
            
                /// The primary ID of the object.
                /// Gets  used to reference models in relationships.
                /// Immutable after insertion into the context.
                @Vein.PrimaryKey
                var id: Vein.ULID
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _updatedAt: Foundation.Date?
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _clientID: String?
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _isDeleted: Bool? = false
            
                required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                    self.id = id
                    self.test = try! String.init(
                        fromPersistent: String.PersistentRepresentation.decode(
                            sqliteValue: fields["test"]!
                        )
                    )!
                    
                    _setupFields()
                }
            
                let _observers = Vein.Mutex(Vein.ReferenceCountedObservers())
            
                /// Sets required properties for @Field values.
                /// Gets generated automatically by @Model.
                public func _setupFields() {
                    self.__clientID.model = self
                    self.__clientID.key = "_clientID"
                    self.__isDeleted.model = self
                    self.__isDeleted.key = "_isDeleted"
                    self.__updatedAt.model = self
                    self.__updatedAt.key = "_updatedAt"
                    self._test.model = self
                    self._test.key = "test"
                    self._id.model = self
                }
            
                let _context = Vein.Mutex<Vein.ManagedObjectContext?>(nil)
            
                /// Whether a model is prepared to be deleted.
                ///
                /// Reading this variable is safe, but it should never be set outside of Vein.
                var _isPreparedForDeletion = false
            
                var _fields: [any Vein.FieldBase] {
                    [
                        self._id,
                        self.__clientID,
                        self.__isDeleted,
                        self.__updatedAt,
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
                        case \\._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                        case \\._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                        case \\._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                        case \\.test: Vein.FieldInformation(String.sqliteTypeName, "test", true)
                        case \\.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                        default: nil
                    }
                }
            
                static let _fieldInformation: [Vein.FieldInformation] = [
                    Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                    Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                    Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
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
        #else
        assertMacroExpansion(
            """
            @Model
            final class Test {
                var test: String // Test
            }
            """,
            expandedSource: """
            final class Test {
                @Vein.Field
                var test: String // Test
            
                /// The primary ID of the object.
                /// Gets  used to reference models in relationships.
                /// Immutable after insertion into the context.
                @Vein.PrimaryKey
                var id: Vein.ULID

                @Vein.LazyField(suppressUIUpdates: true)
                var _updatedAt: Foundation.Date?
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _clientID: String?
            
                @Vein.LazyField(suppressUIUpdates: true)
                var _isDeleted: Bool? = false
            
                required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                    self.id = id
                    self.test = try! String.init(
                        fromPersistent: String.PersistentRepresentation.decode(
                            sqliteValue: fields["test"]!
                        )
                    )!
                    
                    _setupFields()
                }
            
                let _observers = Vein.Mutex(Vein.ReferenceCountedObservers())
            
                /// Sets required properties for @Field values.
                /// Gets generated automatically by @Model.
                public func _setupFields() {
                    self.__clientID.model = self
                    self.__clientID.key = "_clientID"
                    self.__isDeleted.model = self
                    self.__isDeleted.key = "_isDeleted"
                    self.__updatedAt.model = self
                    self.__updatedAt.key = "_updatedAt"
                    self._test.model = self
                    self._test.key = "test"
                    self._id.model = self
                }
            
                let _context = Vein.Mutex<Vein.ManagedObjectContext?>(nil)
            
                /// Whether a model is prepared to be deleted.
                ///
                /// Reading this variable is safe, but it should never be set outside of Vein.
                var _isPreparedForDeletion = false
            
                var _fields: [any Vein.FieldBase] {
                    [
                        self._id,
                        self.__clientID,
                        self.__isDeleted,
                        self.__updatedAt,
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
                        case \\._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                        case \\._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                        case \\._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                        case \\.test: Vein.FieldInformation(String.sqliteTypeName, "test", true)
                        case \\.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                        default: nil
                    }
                }
            
                static let _fieldInformation: [Vein.FieldInformation] = [
                    Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                    Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                    Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
                    Vein.FieldInformation(String.sqliteTypeName, "test", true)
                ]
            
                let objectWillChange = PassthroughSubject<Void, Never>()
            
                var notifyOfChanges: () -> Void {
                    { [weak self] in
                        guard let self else { return }
                        self._observers.value.notifyAll()
                        self.objectWillChange.send()
                    }
                }
            }
            
            extension Test: Vein.PersistentModel, @unchecked Sendable {
                static let schema = "Test"
                static var version: Vein.ModelVersion {
                    Test.version
                }
            }
            
            @MainActor
            extension Test: ObservableObject {
            }
            """,
            macroSpecs: testMacros,
            failureHandler: { spec in
                Issue.record("\(spec.message)")
            }
        )
        #endif
    }
}
