/// This is mostly an implementation detail, currently making your own fields is not supported.
public protocol PersistedField: Sendable, FieldBase {
    var wrappedValue: WrappedType { get set }
}
