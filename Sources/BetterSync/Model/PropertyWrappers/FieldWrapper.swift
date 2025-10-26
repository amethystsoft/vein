import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

@propertyWrapper
public final class LazyField<T: Persistable>: PersistedField, @unchecked Sendable {
    public typealias WrappedType = T?
    
    private let lock = NSLock()
    private var store: T?
    
    /// ONLY LET MACRO SET
    public var key: String?
    /// ONLY LET MACRO SET
    public weak var model: PersistentModel?
    
    public var isLazy: Bool {
        true
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        T.sqliteTypeName
    }
    
    #if canImport(SwiftUI)
    public var projectedValue: Binding<WrappedType> {
        Binding<WrappedType> (
            get: {
                self.wrappedValue
            },
            set: { newValue in
                self.wrappedValue = newValue
            }
        )
    }
    #endif
    
    public var wrappedValue: T? {
        get {
            lock.withLock {
                if let store { return store }
                if let context = model?.context {
                    do {
                        let result = try context.fetchSingleProperty(field: self)
                        lock.withLock {
                            store = result
                        }
                        return result
                    } catch { fatalError(error.localizedDescription) }
                }
                return nil
            }
        }
        set {
            lock.withLock {
                store = newValue
            }
            
            if let context = model?.context {
                do {
                    context.updateDetached(field: self, newValue: newValue)
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }
    }
    
    public func load() async throws {
        guard let context = model?.context else { return }
        let result = try await context.fetchSingleProperty(field: self)
        lock.withLock {
            store = result
        }
    }
    
    public init(wrappedValue: T?) {
        self.store = wrappedValue
        self.key = nil
    }
}

@propertyWrapper
public final class Field<T: Persistable>: PersistedField, @unchecked Sendable {
    public typealias WrappedType = T
    
    public var key: String?
    public weak var model: PersistentModel?
    
    package var store: T
    
    public var isLazy: Bool {
        false
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        T.sqliteTypeName
    }
    
#if canImport(SwiftUI)
    public var projectedValue: Binding<WrappedType> {
        Binding<WrappedType> (
            get: {
                self.wrappedValue
            },
            set: { newValue in
                self.wrappedValue = newValue
            }
        )
    }
#endif
    
    public var wrappedValue: T {
        get {
            return store
        }
        set {
            store = newValue
        }
    }
    
    public init(wrappedValue: T) {
        self.store = wrappedValue
        self.key = nil
    }
}

