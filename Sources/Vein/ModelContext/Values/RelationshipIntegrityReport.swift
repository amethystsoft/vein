import ULID

public struct RelationshipIntegrityReport: Codable {
    public let schema: String
    public let models: [Model]
    
    public struct Model: Codable {
        public let idString: String
        public let localMismatches: [String: Mismatch]
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
            case modelNotFound
        }
        
        public static var corruptedData: Self { Self(kind: .corruptedData) }
        public static var inverseUnexpectedlyNotRelationship: Self {
            Self(kind: .inverseUnexpectedlyNotRelationship)
        }
        public static var missingInInverse: Self {
            Self(kind: .missingInInverse)
        }
        public static var modelNotFound: Self { Self(kind: .modelNotFound) }
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
