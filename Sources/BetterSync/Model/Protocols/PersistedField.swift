@MainActor
public protocol PersistedField {
    associatedtype WrappedType: Persistable
    var key: String? { get }
    var wrappedValue: WrappedType { get }
}

extension PersistedField {
    var instanceKey: String {
        guard let key else {
            fatalError(MOCError.keyMissing(message: "raised by Field property of Type '\(WrappedType.self)'").localizedDescription)
        }
        return key
    }
}
