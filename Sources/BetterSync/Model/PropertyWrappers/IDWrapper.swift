import Foundation

@propertyWrapper
public struct PrimaryKey<T: PersistentIdentifier> {
    public typealias WrappedType = T?
    
    public var wrappedValue: T? {
        didSet {
            print("id did set")
        }
    }
    
    public weak var model: PersistentModel?
    
    public var projectedValue: PersistanceChecker {
        PersistanceChecker(isPersisted: true)
    }
    
    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }
}


public struct PersistanceChecker {
    public var isPersisted: Bool
}
