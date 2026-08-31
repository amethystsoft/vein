// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import Testing
import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
#if TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUIMacros
#elseif TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUIMacros
#else
    @_spi(VeinTesting) @testable import VeinCoreMacros
#endif

fileprivate let testMacros: [String: MacroSpec] = [
    "Model": MacroSpec(type: ModelMacro.self),
    "Relationship": MacroSpec(type: RelationshipMarkerMacro.self)
]

@Suite
struct MacrosTests {
    #if TEST_SCUI
        let sharedSuffix: String = #"""
            var notifyOfChanges: () -> Void {
                    { [weak self] in
                        guard let self else {
                            return
                        }
                        if Thread.isMainThread {
                            self._observers.value.notifyAll()
                            self.didChange.send()
                        } else {
                            DispatchQueue.main.async {
                                self._observers.value.notifyAll()
                                self.didChange.send()
                            }
                        }
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
            extension Test: SwiftCrossUI.ObservableObject {
            }
            """#
    #elseif TEST_SWIFTUI
        let sharedSuffix: String = #"""
            let objectWillChange = Combine.PassthroughSubject<Void, Never>()

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
            extension Test: Combine.ObservableObject {
            }
            """#
    #else
        let sharedSuffix: String = #"""
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
            """#
    #endif

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
            expandedSource: #"""
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

                    @Vein.LazyField(suppressUIUpdates: true)
                    var _isSynced: Bool? = false

                    required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                        self.id = id
                        self.test = try! String.init(
                            fromPersistent: String.PersistentRepresentation.decode(
                                sqliteValue: fields["test"]!
                            )
                        )!
                        
                        _setupFields()
                    }

                    let _observers = Vein.Mutex(Vein._ReferenceCountedObservers())

                    /// Sets required properties for @Field values.
                    /// Gets generated automatically by @Model.
                    public func _setupFields() {
                        self.__clientID._model = self
                        self.__clientID._key = "_clientID"
                        self.__isDeleted._model = self
                        self.__isDeleted._key = "_isDeleted"
                        self.__isSynced._model = self
                        self.__isSynced._key = "_isSynced"
                        self.__updatedAt._model = self
                        self.__updatedAt._key = "_updatedAt"
                        self._test._model = self
                        self._test._key = "test"
                        self._id._model = self
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
                            self.__isSynced,
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
                            case \._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                            case \._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                            case \._isSynced: Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false)
                            case \._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                            case \.test: Vein.FieldInformation(String.sqliteTypeName, "test", true)
                            case \.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                            default: nil
                        }
                    }

                    static let _fieldInformation: [Vein.FieldInformation] = [
                        Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false),
                        Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
                        Vein.FieldInformation(String.sqliteTypeName, "test", true)
                    ]

                    \#(sharedSuffix)
                """#,
            diagnostics: [
                DiagnosticSpec(
                    message: "Models need to be enclosed in a VersionedSchema enum. Otherwise they will not function correctly.",
                    line: 1,
                    column: 1
                )
            ],
            macroSpecs: testMacros,
            failureHandler: { spec in
                Issue.record("\(spec.message)")
            }
        )
    }

    @Test
    func fieldAutogenerationWorks() async throws {
        assertMacroExpansion(
            """
            @Model
            final class Test {
                var test: String // Test
            }
            """,
            expandedSource: #"""
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

                    @Vein.LazyField(suppressUIUpdates: true)
                    var _isSynced: Bool? = false

                    required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                        self.id = id
                        self.test = try! String.init(
                            fromPersistent: String.PersistentRepresentation.decode(
                                sqliteValue: fields["test"]!
                            )
                        )!
                        
                        _setupFields()
                    }

                    let _observers = Vein.Mutex(Vein._ReferenceCountedObservers())

                    /// Sets required properties for @Field values.
                    /// Gets generated automatically by @Model.
                    public func _setupFields() {
                        self.__clientID._model = self
                        self.__clientID._key = "_clientID"
                        self.__isDeleted._model = self
                        self.__isDeleted._key = "_isDeleted"
                        self.__isSynced._model = self
                        self.__isSynced._key = "_isSynced"
                        self.__updatedAt._model = self
                        self.__updatedAt._key = "_updatedAt"
                        self._test._model = self
                        self._test._key = "test"
                        self._id._model = self
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
                            self.__isSynced,
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
                            case \._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                            case \._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                            case \._isSynced: Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false)
                            case \._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                            case \.test: Vein.FieldInformation(String.sqliteTypeName, "test", true)
                            case \.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                            default: nil
                        }
                    }

                    static let _fieldInformation: [Vein.FieldInformation] = [
                        Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false),
                        Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
                        Vein.FieldInformation(String.sqliteTypeName, "test", true)
                    ]

                    \#(sharedSuffix)
                """#,
            diagnostics: [
                DiagnosticSpec(
                    message: "Models need to be enclosed in a VersionedSchema enum. Otherwise they will not function correctly.",
                    line: 1,
                    column: 1
                )
            ],
            macroSpecs: testMacros,
            failureHandler: { spec in
                Issue.record("\(spec.message)")
            }
        )
    }

    @Test
    func writingToRelationshipUsingSelfDiagnoses() throws {
        assertMacroExpansion(
            """
            @Model
            final class Test {
                @Relationship
                var doNotUseInInit: Test?

                init() {
                    self.doNotUseInInit = nil
                }
            }
            """,
            expandedSource: #"""
                final class Test {
                    @Vein._OneRelationship()
                    var doNotUseInInit: Test?

                    init() {
                        self.doNotUseInInit = nil
                    }

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

                    @Vein.LazyField(suppressUIUpdates: true)
                    var _isSynced: Bool? = false

                    required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                        self.id = id
                        
                        self._doNotUseInInit._persistableValue = try! ULID?.init(
                            fromPersistent: ULID?.PersistentRepresentation.decode(
                                sqliteValue: fields["doNotUseInInit"]!
                            )
                        )!
                        _setupFields()
                    }

                    let _observers = Vein.Mutex(Vein._ReferenceCountedObservers())

                    /// Sets required properties for @Field values.
                    /// Gets generated automatically by @Model.
                    public func _setupFields() {
                        self.__clientID._model = self
                        self.__clientID._key = "_clientID"
                        self.__isDeleted._model = self
                        self.__isDeleted._key = "_isDeleted"
                        self.__isSynced._model = self
                        self.__isSynced._key = "_isSynced"
                        self.__updatedAt._model = self
                        self.__updatedAt._key = "_updatedAt"
                        self._doNotUseInInit._model = self
                        self._doNotUseInInit._key = "doNotUseInInit"
                        self._id._model = self
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
                            self.__isSynced,
                            self.__updatedAt,
                            self._doNotUseInInit
                        ]
                    }

                    var _relationships: [any Vein.PersistedRelationship] {
                        [
                            self._doNotUseInInit
                        ]
                    }

                    static let _inverseFields = {
                        var map = [ObjectIdentifier: [String: String]]()
                        
                        return map
                    }()

                    static func _predicateInformation(for keyPath: PartialKeyPath<Test>) -> Vein.FieldInformation? {
                        switch keyPath {
                            case \._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                            case \._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                            case \._isSynced: Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false)
                            case \._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                            case \.doNotUseInInit: Vein.FieldInformation(ULID?.sqliteTypeName, "doNotUseInInit", true, Test.self)
                            case \.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                            default: nil
                        }
                    }

                    static let _fieldInformation: [Vein.FieldInformation] = [
                        Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false),
                        Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
                        Vein.FieldInformation(ULID?.sqliteTypeName, "doNotUseInInit", true, Test.self)
                    ]

                    \#(sharedSuffix)
                """#,
            diagnostics: [
                DiagnosticSpec(
                    message: "Illegal assignment to relationship property in initializer. Relationships require the model to be managed by a context.",
                    line: 7,
                    column: 9
                ),
                DiagnosticSpec(
                    message: "Models need to be enclosed in a VersionedSchema enum. Otherwise they will not function correctly.",
                    line: 1,
                    column: 1
                ),
            ],
            macroSpecs: testMacros,
            failureHandler: { spec in
                Issue.record("\(spec.message)")
            }
        )
    }

    @Test
    func writingToRelationshipWithoutSelfDiagnoses() throws {
        assertMacroExpansion(
            """
            @Model
            final class Test {
                @Relationship
                var doNotUseInInit: Test?

                init() {
                    doNotUseInInit = nil
                }
            }
            """,
            expandedSource: #"""
                final class Test {
                    @Vein._OneRelationship()
                    var doNotUseInInit: Test?

                    init() {
                        doNotUseInInit = nil
                    }

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

                    @Vein.LazyField(suppressUIUpdates: true)
                    var _isSynced: Bool? = false

                    required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                        self.id = id
                        
                        self._doNotUseInInit._persistableValue = try! ULID?.init(
                            fromPersistent: ULID?.PersistentRepresentation.decode(
                                sqliteValue: fields["doNotUseInInit"]!
                            )
                        )!
                        _setupFields()
                    }

                    let _observers = Vein.Mutex(Vein._ReferenceCountedObservers())

                    /// Sets required properties for @Field values.
                    /// Gets generated automatically by @Model.
                    public func _setupFields() {
                        self.__clientID._model = self
                        self.__clientID._key = "_clientID"
                        self.__isDeleted._model = self
                        self.__isDeleted._key = "_isDeleted"
                        self.__isSynced._model = self
                        self.__isSynced._key = "_isSynced"
                        self.__updatedAt._model = self
                        self.__updatedAt._key = "_updatedAt"
                        self._doNotUseInInit._model = self
                        self._doNotUseInInit._key = "doNotUseInInit"
                        self._id._model = self
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
                            self.__isSynced,
                            self.__updatedAt,
                            self._doNotUseInInit
                        ]
                    }

                    var _relationships: [any Vein.PersistedRelationship] {
                        [
                            self._doNotUseInInit
                        ]
                    }

                    static let _inverseFields = {
                        var map = [ObjectIdentifier: [String: String]]()
                        
                        return map
                    }()

                    static func _predicateInformation(for keyPath: PartialKeyPath<Test>) -> Vein.FieldInformation? {
                        switch keyPath {
                            case \._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                            case \._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                            case \._isSynced: Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false)
                            case \._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                            case \.doNotUseInInit: Vein.FieldInformation(ULID?.sqliteTypeName, "doNotUseInInit", true, Test.self)
                            case \.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                            default: nil
                        }
                    }

                    static let _fieldInformation: [Vein.FieldInformation] = [
                        Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false),
                        Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
                        Vein.FieldInformation(ULID?.sqliteTypeName, "doNotUseInInit", true, Test.self)
                    ]

                    \#(sharedSuffix)
                """#,
            diagnostics: [
                DiagnosticSpec(
                    message: "Illegal assignment to relationship property in initializer. Relationships require the model to be managed by a context.",
                    line: 7,
                    column: 9
                ),
                DiagnosticSpec(
                    message: "Models need to be enclosed in a VersionedSchema enum. Otherwise they will not function correctly.",
                    line: 1,
                    column: 1
                ),
            ],
            macroSpecs: testMacros,
            failureHandler: { spec in
                Issue.record("\(spec.message)")
            }
        )
    }

    @Test
    func diagnosesOnlyThingsHittingSelf() throws {
        assertMacroExpansion(
            """
            @Model
            final class Test {
                @Relationship
                var doNotUseInInit: Test?

                init() {
                    if true {
                        var doNotUseInInit = 1
                        doNotUseInInit = 2
                        self.doNotUseInInit = nil
                    }
                    self.doNotUseInInit = nil
                    doNotUseInInit = nil
                }
            }
            """,
            expandedSource: #"""
                final class Test {
                    @Vein._OneRelationship()
                    var doNotUseInInit: Test?

                    init() {
                        if true {
                            var doNotUseInInit = 1
                            doNotUseInInit = 2
                            self.doNotUseInInit = nil
                        }
                        self.doNotUseInInit = nil
                        doNotUseInInit = nil
                    }

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

                    @Vein.LazyField(suppressUIUpdates: true)
                    var _isSynced: Bool? = false

                    required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
                        self.id = id
                        
                        self._doNotUseInInit._persistableValue = try! ULID?.init(
                            fromPersistent: ULID?.PersistentRepresentation.decode(
                                sqliteValue: fields["doNotUseInInit"]!
                            )
                        )!
                        _setupFields()
                    }

                    let _observers = Vein.Mutex(Vein._ReferenceCountedObservers())

                    /// Sets required properties for @Field values.
                    /// Gets generated automatically by @Model.
                    public func _setupFields() {
                        self.__clientID._model = self
                        self.__clientID._key = "_clientID"
                        self.__isDeleted._model = self
                        self.__isDeleted._key = "_isDeleted"
                        self.__isSynced._model = self
                        self.__isSynced._key = "_isSynced"
                        self.__updatedAt._model = self
                        self.__updatedAt._key = "_updatedAt"
                        self._doNotUseInInit._model = self
                        self._doNotUseInInit._key = "doNotUseInInit"
                        self._id._model = self
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
                            self.__isSynced,
                            self.__updatedAt,
                            self._doNotUseInInit
                        ]
                    }

                    var _relationships: [any Vein.PersistedRelationship] {
                        [
                            self._doNotUseInInit
                        ]
                    }

                    static let _inverseFields = {
                        var map = [ObjectIdentifier: [String: String]]()
                        
                        return map
                    }()

                    static func _predicateInformation(for keyPath: PartialKeyPath<Test>) -> Vein.FieldInformation? {
                        switch keyPath {
                            case \._clientID: Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false)
                            case \._isDeleted: Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false)
                            case \._isSynced: Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false)
                            case \._updatedAt: Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false)
                            case \.doNotUseInInit: Vein.FieldInformation(ULID?.sqliteTypeName, "doNotUseInInit", true, Test.self)
                            case \.id: Vein.FieldInformation(ULID.sqliteTypeName, "id", true)
                            default: nil
                        }
                    }

                    static let _fieldInformation: [Vein.FieldInformation] = [
                        Vein.FieldInformation(String?.sqliteTypeName, "_clientID", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isDeleted", false),
                        Vein.FieldInformation(Bool?.sqliteTypeName, "_isSynced", false),
                        Vein.FieldInformation(Foundation.Date?.sqliteTypeName, "_updatedAt", false),
                        Vein.FieldInformation(ULID?.sqliteTypeName, "doNotUseInInit", true, Test.self)
                    ]

                    \#(sharedSuffix)
                """#,
            diagnostics: [
                DiagnosticSpec(
                    message: "Illegal assignment to relationship property in initializer. Relationships require the model to be managed by a context.",
                    line: 10,
                    column: 13
                ),
                DiagnosticSpec(
                    message: "Illegal assignment to relationship property in initializer. Relationships require the model to be managed by a context.",
                    line: 12,
                    column: 9
                ),
                DiagnosticSpec(
                    message: "Illegal assignment to relationship property in initializer. Relationships require the model to be managed by a context.",
                    line: 13,
                    column: 9
                ),
                DiagnosticSpec(
                    message: "Models need to be enclosed in a VersionedSchema enum. Otherwise they will not function correctly.",
                    line: 1,
                    column: 1
                ),
            ],
            macroSpecs: testMacros,
            failureHandler: { spec in
                Issue.record("\(spec.message)")
            }
        )
    }
}
