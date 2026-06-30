import Vein

extension ManagedObjectContext {
    public nonisolated var callBeforeChange: Bool { true }
}

extension Field {
    public var callBeforeChange: Bool { true }
}

extension LazyField {
    public var callBeforeChange: Bool { true }
}

extension _OneRelationship {
    public var callBeforeChange: Bool { true }
}

extension _ManyRelationship {
    public var callBeforeChange: Bool { true }
}
