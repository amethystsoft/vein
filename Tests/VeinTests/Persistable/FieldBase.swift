import Foundation
import Testing
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct FieldBaseTests {
    func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(
            V1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.test.FieldBase",
            encryptionEnabled: false
        )
    }
    
    @Test
    func decodeNormalAndNil() throws {
        let container = try makeModelContainer()
        let ulid = ULID()
        let jsonBULID = SQLiteJSONB(jsonString: "[\"\(ulid.ulidString)\"]")
        let test = Test(
            int: 1,
            real: 2,
            text: "3",
            blob: "4".data(using: .utf8)!,
            jsonB: [ulid]
        )
        
        try container.context.insert(test)
        try container.context.save()
        
        let connection = container.getConnection()
        let toFetch = Test._fieldInformation.map(\.fetchExpressible)
        let query = Table(Test.schema)
            .select(toFetch)
            .limit(1)
        let rows = try connection.prepare(query)
        for row in rows {
            #expect(test.intField.decode(row) == 1)
            #expect(test.realField.decode(row) == 2)
            #expect(test.textField.decode(row) == "3")
            #expect(test.blobField.decode(row) == "4".data(using: .utf8))
            #expect(test.jsonBField.decode(row) == jsonBULID)
            #expect(test.optIntField.decode(row) == nil)
            #expect(test.optRealField.decode(row) == nil)
            #expect(test.optTextField.decode(row) == nil)
            #expect(test.optBlobField.decode(row) == nil)
            #expect(test.optJsonBField.decode(row) == nil)
        }
    }
    
    @Test
    func decodeOptFilled() throws {
        let container = try makeModelContainer()
        let ulid = ULID()
        let jsonBULID = SQLiteJSONB(jsonString: "[\"\(ulid.ulidString)\"]")
        let test = Test(
            int: 1,
            real: 2,
            text: "3",
            blob: "4".data(using: .utf8)!,
            jsonB: [ulid],
            optInt: 1,
            optReal: 2,
            optText: "3",
            optBlob: "4".data(using: .utf8)!,
            optJsonB: [ulid]
        )
        
        try container.context.insert(test)
        try container.context.save()
        
        let connection = container.getConnection()
        let toFetch = Test._fieldInformation.map(\.fetchExpressible)
        let query = Table(Test.schema)
            .select(toFetch)
            .limit(1)
        let rows = try connection.prepare(query)
        for row in rows {
            #expect(test.intField.decode(row) == 1)
            #expect(test.realField.decode(row) == 2)
            #expect(test.textField.decode(row) == "3")
            #expect(test.blobField.decode(row) == "4".data(using: .utf8))
            #expect(test.jsonBField.decode(row) == jsonBULID)
            #expect(test.optIntField.decode(row) == 1)
            #expect(test.optRealField.decode(row) == 2)
            #expect(test.optTextField.decode(row) == "3")
            #expect(test.optBlobField.decode(row) == "4".data(using: .utf8))
            #expect(test.optJsonBField.decode(row) == [ulid])
        }
    }
}

fileprivate enum V1: VersionedSchema {
    static let version: Vein.ModelVersion = .init(1, 0, 0)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test {
        var int: Int
        var real: Double
        var text: String
        var blob: Data
        var jsonB: [ULID]
        
        var optInt: Int?
        var optReal: Double?
        var optText: String?
        var optBlob: Data?
        var optJsonB: [ULID]?
        
        var intField: Field<Int> { _int }
        var realField: Field<Double> { _real }
        var textField: Field<String> { _text }
        var blobField: Field<Data> { _blob }
        var jsonBField: Field<[ULID]> { _jsonB }
        var optIntField: Field<Int?> { _optInt }
        var optRealField: Field<Double?> { _optReal }
        var optTextField: Field<String?> { _optText }
        var optBlobField: Field<Data?> { _optBlob }
        var optJsonBField: Field<[ULID]?> { _optJsonB }
        
        init(
            int: Int,
            real: Double,
            text: String,
            blob: Data,
            jsonB: [ULID],
            optInt: Int? = nil,
            optReal: Double? = nil,
            optText: String? = nil,
            optBlob: Data? = nil,
            optJsonB: [ULID]? = nil
        ) {
            self.int = int
            self.real = real
            self.text = text
            self.blob = blob
            self.jsonB = jsonB
            self.optInt = optInt
            self.optReal = optReal
            self.optText = optText
            self.optBlob = optBlob
            self.optJsonB = optJsonB
        }
    }
}

fileprivate typealias Test = V1.Test

fileprivate enum Migration: SchemaMigrationPlan {
    static let stages: [Vein.MigrationStage] = []
    
    static let schemas: [any Vein.VersionedSchema.Type] = [V1.self]
}
