import SQLiteDB
public enum _Autoheal: String, CaseIterable {
    case v1_1_1_relationshipReferenceFix
}

extension _Autoheal {
    public var versionIntroduced: ModelVersion {
        return switch self {
            case .v1_1_1_relationshipReferenceFix:
                ModelVersion(1, 1, 1)
        }
    }
    
    var implementation: AutohealImplementation {
        switch self {
            case .v1_1_1_relationshipReferenceFix:
                Vein1_1_1RelationshipReferenceBalanceHeal()
        }
    }
    
    func run(_ container: ModelContainer) throws {
        try implementation.run(with: container)
    }
}

protocol AutohealImplementation {
    nonisolated func run(with container: ModelContainer) throws
}
