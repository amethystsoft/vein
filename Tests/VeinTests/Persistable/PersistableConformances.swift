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

// These tests feels insanely stupid. But in theory someone could break
// the implementations, so I'm just gonna put it here to prevent this unlikely case.
@Suite
struct PersistableConformances {
    @Test
    func asPersistentRepresentation() {
        #expect(Int(4).asPersistentRepresentation == Int(4))
        #expect(Int16(4).asPersistentRepresentation == Int16(4))
        #expect(Int32(4).asPersistentRepresentation == Int32(4))
        #expect(Int64(4).asPersistentRepresentation == Int64(4))
        #expect(Double(4).asPersistentRepresentation == Double(4))
        #expect(Float(4).asPersistentRepresentation == Float(4))
        #expect(true.asPersistentRepresentation == true)
        #expect("4".asPersistentRepresentation == "4")
        #expect("4".data(using: .utf8)?.asPersistentRepresentation == "4".data(using: .utf8))

        let jsonB = SQLiteJSONB(jsonString: "[]")
        #expect(jsonB.asPersistentRepresentation == jsonB)
        let ulid = ULID()
        let ulidJSONB = SQLiteJSONB(jsonString: "[\"\(ulid.ulidString)\"]")
        #expect(ulid.asPersistentRepresentation == ulid.ulidString)
        #expect([ulid].asPersistentRepresentation == ulidJSONB)
        let url = URL(string: "https://vein.amethystsoft.de")
        #expect(url?.asPersistentRepresentation == "https://vein.amethystsoft.de")
        let uuid = UUID()
        #expect(uuid.asPersistentRepresentation == uuid)
        #expect(Int?.none?.asPersistentRepresentation == nil)
        #expect(Int?(4)?.asPersistentRepresentation == 4)
    }

    @Test
    func sqliteValue() {
        #expect(Int(4).asPersistentRepresentation.sqliteValue == .integer(4))
        #expect(Int16(4).sqliteValue == .integer(4))
        #expect(Int32(4).sqliteValue == .integer(4))
        #expect(Int64(4).sqliteValue == .integer(4))
        #expect(Double(4).sqliteValue == .real(4))
        #expect(Float(4).sqliteValue == .real(4))
        #expect(true.sqliteValue == .integer(1))
        #expect(false.sqliteValue == .integer(0))
        #expect("4".sqliteValue == .text("4"))
        #expect("4".data(using: .utf8)?.sqliteValue == .blob("4".data(using: .utf8)!))

        let jsonB = SQLiteJSONB(jsonString: "[]")
        #expect(jsonB.sqliteValue == .text(jsonB.jsonString))
        let ulid = ULID()
        let ulidJSONB = SQLiteJSONB(jsonString: "[\"\(ulid.ulidString)\"]")
        #expect(ulid.asPersistentRepresentation.sqliteValue == .text(ulid.ulidString))
        #expect([ulid].asPersistentRepresentation.sqliteValue == .text(ulidJSONB.jsonString))
        let url = URL(string: "https://vein.amethystsoft.de")
        #expect(url?.asPersistentRepresentation
            .sqliteValue == .text("https://vein.amethystsoft.de"))
        let uuid = UUID()
        #expect(uuid.sqliteValue == .text(uuid.uuidString))
        #expect(Int?.none.asPersistentRepresentation.sqliteValue == .null)
        let int: Int? = 4
        #expect(int.sqliteValue == .integer(4))
    }

    @Test
    func decode() throws {
        try #expect(Int64.decode(sqliteValue: .integer(4)) == Int64(4))
        try #expect(Int32.decode(sqliteValue: .integer(4)) == Int32(4))
        try #expect(Int16.decode(sqliteValue: .integer(4)) == Int16(4))
        try #expect(Double.decode(sqliteValue: .real(4)) == Double(4))
        try #expect(Float.decode(sqliteValue: .real(4)) == Float(4))
        try #expect(Bool.decode(sqliteValue: .integer(1)) == true)
        try #expect(Bool.decode(sqliteValue: .integer(0)) == false)
        try #expect(String.decode(sqliteValue: .text("4")) == "4")
        let data = "4".data(using: .utf8)!
        try #expect(Data.decode(sqliteValue: .blob(data)) == data)

        let jsonB = SQLiteJSONB(jsonString: "[]")
        try #expect(SQLiteJSONB.decode(sqliteValue: .text("[]")) == jsonB)
        let uuid = UUID()
        try #expect(UUID.decode(sqliteValue: .text(uuid.uuidString)) == uuid)
        try #expect(Int?.decode(sqliteValue: .null) == nil)
        try #expect(Int?.decode(sqliteValue: .integer(4)) == 4)
    }

    @Test
    func `init(fromPersistent:)`() {
        #expect(Int64(fromPersistent: 4) == 4)
        #expect(Int32(fromPersistent: 4) == 4)
        #expect(Int16(fromPersistent: 4) == 4)
        #expect(Int(fromPersistent: 4) == 4)
        #expect(Double(fromPersistent: 4) == 4)
        #expect(Float(fromPersistent: 4) == 4)
        #expect(String(fromPersistent: "4") == "4")
        #expect(Bool(fromPersistent: false) == false)
        #expect(Bool(fromPersistent: true) == true)
        let data = "4".data(using: .utf8)!
        #expect(Data(fromPersistent: data) == data)
        let ulid = ULID()
        let ulidJSONB = SQLiteJSONB(jsonString: "[\"\(ulid.ulidString)\"]")
        #expect(ULID(fromPersistent: ulid.ulidString) == ulid)
        #expect([ULID](fromPersistent: ulidJSONB) == [ulid])
        let url = URL(string: "https://vein.amethystsoft.de")
        #expect(URL(fromPersistent: "https://vein.amethystsoft.de") == url)
        let uuid = UUID()
        #expect(UUID(fromPersistent: uuid) == uuid)
        #expect(Int?(fromPersistent: nil) == Int?.none)
        let int: Int? = 4
        #expect(Int?(fromPersistent: int) == 4)
    }
}

extension SQLiteValue: Comparable {
    public static func < (
        lhs: borrowing Vein.SQLiteValue,
        rhs: borrowing Vein.SQLiteValue
    ) -> Bool {
        false
    }

    public static func == (lhs: SQLiteValue, rhs: SQLiteValue) -> Bool {
        if
            case .integer(let int1) = lhs,
            case .integer(let int2) = rhs
        { return int1 == int2 }
        if
            case .real(let double1) = lhs,
            case .real(let double2) = rhs
        { return double1 == double2 }
        if
            case .blob(let blob1) = lhs,
            case .blob(let blob2) = rhs
        { return blob1 == blob2 }
        if
            case .text(let text1) = lhs,
            case .text(let text2) = rhs
        { return text1 == text2 }
        if
            case .null = lhs,
            case .null = rhs
        { return true }
        return false
    }
}
