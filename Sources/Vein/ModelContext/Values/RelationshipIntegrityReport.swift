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
import ULID

public struct RelationshipIntegrityReport: Codable {
    public let schema: String
    public let models: [Model]

    public struct Model: Codable {
        public let idString: String
        /// field, mismatch
        public let localMismatches: [String: Mismatch]
        /// field, id on other side, mismatch
        public let inverseMismatches: [String: [String: Mismatch]]

        public var id: ULID? {
            ULID(ulidString: idString)
        }
    }

    public struct Mismatch: Codable {
        public let kind: Kind
        public enum Kind: Codable {
            case corruptedData
            case inverseCountMismatch(found: Int, expected: Int)
            case missingInInverse
            case inverseUnexpectedlyNotRelationship
            case unexpectedlyNotRelationship
            case inverseMismatch(found: ULID?, expected: ULID)
        }

        public static var corruptedData: Self { Self(kind: .corruptedData) }
        public static var inverseUnexpectedlyNotRelationship: Self {
            Self(kind: .inverseUnexpectedlyNotRelationship)
        }
        public static var missingInInverse: Self {
            Self(kind: .missingInInverse)
        }
        public static var unexpectedlyNotRelationship: Self {
            Self(kind: .unexpectedlyNotRelationship)
        }
        public static func inverseCountMismatch(found: Int, expected: Int) -> Self {
            Self(kind: .inverseCountMismatch(found: found, expected: expected))
        }
        public static func inverseMismatch(found: ULID?, expected: ULID) -> Self {
            Self(kind: .inverseMismatch(found: found, expected: expected))
        }
    }
}

extension RelationshipIntegrityReport {
    var didPass: Bool {
        models.isEmpty
    }
}

extension RelationshipIntegrityReport.Mismatch.Kind {
    var description: String {
        switch self {
            case .corruptedData:
                "corruptedData"
            case .inverseCountMismatch(let found, let expected):
                "inverseCountMismatch: found: \(found), expected: \(expected)"
            case .missingInInverse:
                "missingInInverse"
            case .inverseUnexpectedlyNotRelationship:
                "inverseUnexpectedlyNotRelationship"
            case .unexpectedlyNotRelationship:
                "unexpectedlyNotRelationship"
            case .inverseMismatch(let found, let expected):
                "inverseMismatch: found: \(found?.ulidString ?? "nil"), expected: \(expected.ulidString)"
        }
    }
}

extension RelationshipIntegrityReport.Mismatch: Equatable {
    public static func == (
        lhs: borrowing RelationshipIntegrityReport.Mismatch,
        rhs: borrowing RelationshipIntegrityReport.Mismatch
    ) -> Bool {
        return lhs.kind.description == rhs.kind.description
    }
}
