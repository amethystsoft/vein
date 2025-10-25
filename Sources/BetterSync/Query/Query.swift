import SQLite

@MainActor
@propertyWrapper
public struct Query<M: PersistentModel> {
    public typealias WrappedType = [M]
    
    public var wrappedValue: [M] {
        get {
            do {
                return try ManagedObjectContext.instance.fetchAll(M.self)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    public init() { }
}
