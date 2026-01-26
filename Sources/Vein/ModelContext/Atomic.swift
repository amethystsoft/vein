import Foundation

public final class Atomic<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    public init(_ value: Value) {
        self._value = value
    }

    /// Use `set` only for blind overwrited
    /// Changing arrays or dictionaries based on their
    /// current value must be done in ``Atomic/mutate(_)``
    public var value: Value {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
    
    /// Mutate the content in a thread-safe way
    public func mutate<R>(_ body: (inout Value) -> R) -> R {
        lock.withLock { body(&_value) }
    }
    
    public func mutate<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        try lock.withLock{ try body(&_value) }
    }
}
