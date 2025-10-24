import Foundation

@propertyWrapper
public struct PrimaryKey: PersistedField {
    public typealias WrappedType = UUID?
    
    public let key: String? = "id"
    
    public var wrappedValue: UUID? {
        didSet {
            print("id did set")
        }
    }
    
    public weak var model: PersistentModel?
    
    public var projectedValue: PersistanceChecker {
        PersistanceChecker {
            self.model?.context != nil
        }
    }
    
    public init(wrappedValue: UUID?) {
        self.wrappedValue = wrappedValue
    }
}


public struct PersistanceChecker {
    private let getPersistanceState: () -> Bool
    package init(getPersistanceState: @escaping () -> Bool) {
        self.getPersistanceState = getPersistanceState
    }
    public var isPersisted: Bool {
        getPersistanceState()
    }
}
