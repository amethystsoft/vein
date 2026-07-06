import ULID

public protocol PersistedRelationship: FieldBase {
    associatedtype Value
    var wrappedValue: Value { get set }
    func _handleModelDeletion()
    var wasTouched: Bool { get set }
}

public protocol ManyRelationship: PersistedRelationship {
    var _persistableValue: [ULID] { get set }
}
public protocol OneRelationship: PersistedRelationship {
    var _persistableValue: ULID? { get set }
}

public enum DeleteRule {
    case nullify
    case cascade
}
