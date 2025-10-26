import SwiftUI
import BetterSync
import Combine

/*@propertyWrapper
public struct Query<T: PersistentModel>: DynamicProperty {
    @State private var results: [T] = []
    
    public init() {}
    
    public var wrappedValue: [T] {
        results
    }
    
    public func update() {
        do {
            results = try ManagedObjectContext.instance.fetchAll(T.self)
        } catch {
            print("Fetch error: \(error)")
            results = []
        }
    }
}*/
/*
@propertyWrapper
public struct Query<T: PersistentModel>: DynamicProperty {
    @State private var results: [T] = []
    
    public init() {}
    
    public var wrappedValue: [T] {
        results
    }
    
    public var projectedValue: Binding<[T]> {
        $results
    }
}
*/

@MainActor
@propertyWrapper
public class Query<M: PersistentModel>: DynamicProperty {
    public typealias WrappedType = [M]
    
    @State private var cachedItems: [M]?
    
    public var wrappedValue: [M] {
        if let cached = cachedItems {
            return cached
        }
        do {
            let items = try ManagedObjectContext.instance.fetchAll(M.self)
            
            self.cachedItems = items
            
            return items
            
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    public init() { }
}

