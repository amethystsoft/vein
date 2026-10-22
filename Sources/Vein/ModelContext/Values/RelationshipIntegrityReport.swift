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
    /// The schema checked.
    public let schema: String
    /// The rows an issue was found with.
    public let models: [Model]

    public struct Model: Codable {
        /// The primary key of the scanned row.
        public let idString: String
        /// Mismatches in the current row, keyed by field name.
        public let localMismatches: [String: Mismatch]
        /// Mismatches in the inverses of the current row.
        /// First keyed by the field whose inverse it's looking at,
        /// then by the id an issue was detected with from the references of said field.
        public let inverseMismatches: [String: [String: Mismatch]]

        /// The id of the scanned row or `nil` if the primary key is not a valid ULID.
        public var id: ULID? {
            ULID(ulidString: idString)
        }
    }

    public struct Mismatch: Codable {
        public let kind: Kind
        @nonexhaustive
        public enum Kind: Codable {
            /// The field is corrupted.
            case corruptedData
            /// The amount of references to the current row doesn't match the amount required by the field.
            case inverseCountMismatch(found: Int, expected: Int)
            /// Row for the given ID was not found in the inverse table.
            case missingInInverse
            /// The type of the inverse field doesn't fit a relationship.
            case inverseUnexpectedlyNotRelationship
            /// The type of the field declared as relationship didn't fit a relationship.
            case unexpectedlyNotRelationship
            /// The id value of the inverse field doesn't point to the ulid of the current row.
            case inverseMismatch(found: String?, expected: String)
        }

        /// The field is corrupted.
        public static var corruptedData: Self { Self(kind: .corruptedData) }
        /// The type of the inverse field doesn't fit a relationship.
        public static var inverseUnexpectedlyNotRelationship: Self {
            Self(kind: .inverseUnexpectedlyNotRelationship)
        }
        /// Row for the given ID was not found in the inverse table.
        public static var missingInInverse: Self {
            Self(kind: .missingInInverse)
        }
        /// The type of the field declared as relationship didn't fit a relationship.
        public static var unexpectedlyNotRelationship: Self {
            Self(kind: .unexpectedlyNotRelationship)
        }
        /// The amount of references to the current row doesn't match the amount required by the field.
        public static func inverseCountMismatch(found: Int, expected: Int) -> Self {
            Self(kind: .inverseCountMismatch(found: found, expected: expected))
        }
        /// The id value of the inverse field doesn't point to the id of the current row.
        public static func inverseMismatch(found: String?, expected: String) -> Self {
            Self(kind: .inverseMismatch(found: found, expected: expected))
        }
    }
}

extension RelationshipIntegrityReport {
    /// Whether the integrity check passed without errors.
    public var didPass: Bool {
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
                "inverseMismatch: found: \(found ?? "nil"), expected: \(expected)"
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
