public protocol PersistedRelationship {
    associatedtype WrappedType: PersistentModel
    associatedtype PersistableRepresentation: Persistable
    var key: String? { get }
    var wrappedValue: WrappedType? { get set }
    var model: (any PersistentModel)? { get }
    func setStoreToCapturedState(_ state: Any)
    var wasTouched: Bool { get }
    
    var persistentRepresentation: PersistableRepresentation { get set }
}
