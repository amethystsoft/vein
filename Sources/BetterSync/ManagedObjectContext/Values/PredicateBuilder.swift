import SQLite

public protocol PredicateConstructor: Sendable {
    associatedtype Model: PersistentModel
    func _builder() -> PredicateBuilder<Model>
    
    init()
}

public struct PredicateBuilder<T: PersistentModel>: Sendable, Hashable, AnyPredicateBuilder {
    public static func == (lhs: PredicateBuilder<T>, rhs: PredicateBuilder<T>) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    public private(set) var hashValue: Int
    private var conditions = Expression<Bool?>(value: true)
    private var checkMatching: (T) -> Bool = { _ in true }
    
    public init() {
        self.hashValue = ObjectIdentifier(T.self).hashValue
    }
    
    /// Its unsafe to call this yourself.
    /// It will likely result in a crash.
    /// Only intended to get used by macro generated code.
    @discardableResult
    public func addCheck<V: Persistable>(_ op: ComparisonOperator, _ key: String, _ value: V) -> Self {
        switch op {
            case .isEqualTo: equal(key, value)
            case .isNotEqualTo: notEqual(key, value)
            case .isBiggerThan: bigger(key, value)
            case .isSmallerThan: smaller(key, value)
            case .isBiggerOrEqualTo: biggerOrEqual(key, value)
            case .isSmallerOrEqualTo: smallerOrEqual(key, value)
        }
    }
    
    private func equal<V: Persistable>(_ key: String,
                             _ value: V) -> Self {
        let sqliteValue = sqliteValue(from: value)
            
        let next = V.sqliteTypeName.fieldIsEqualToExpression(
            key: key,
            value: sqliteValue.underlyingValue(
                withTypeName: V.sqliteTypeName
            )
        )
        
        var old = self
        old.checkMatching = { model in
            checkMatching(model) &&
            self.sqliteValue(
                from: model
                    ._fields
                    .first(
                        where: { $0.instanceKey == key }
                    )!
                    .wrappedValue as! V
            )
            .fieldIsEqualTo(
                sqliteValue
                    .underlyingValue(
                        withTypeName: V.sqliteTypeName
                    ),
                withTypeName:
                    value.asPersistentRepresentation
                    .sqliteTypeName
            )
        }
        old.conditions = old.conditions && next
        old.hashValue = newHash(next, sqliteValue)
        return old
    }
    
    private func notEqual<V: Persistable>(_ key: String,
                                       _ value: V) -> Self {
        let sqliteValue = sqliteValue(from: value)
        
        let next = V.sqliteTypeName.fieldIsEqualToExpression(
            key: key,
            value: sqliteValue.underlyingValue(
                withTypeName: V.sqliteTypeName
            )
        )
        var old = self
        old.checkMatching = { model in
            checkMatching(model) &&
            self.sqliteValue(
                from: model
                    ._fields
                    .first(
                        where: { $0.instanceKey == key }
                    )!
                    .wrappedValue as! V
            )
            .fieldIsNotEqualTo(
                sqliteValue
                    .underlyingValue(
                        withTypeName: V.sqliteTypeName
                    ),
                withTypeName:
                    value.asPersistentRepresentation
                    .sqliteTypeName
            )
        }
        old.conditions = old.conditions && next
        old.hashValue = newHash(next, sqliteValue)
        return old
    }
    
    private func bigger<V: Persistable>(_ key: String,
                                       _ value: V) -> Self {
        let sqliteValue = sqliteValue(from: value)
        
        let next = V.sqliteTypeName.fieldIsBiggerToExpression(
            key: key,
            value: sqliteValue
                .underlyingValue(
                    withTypeName: V.sqliteTypeName
                )
        )
        var old = self
        old.checkMatching = { model in
            checkMatching(model) &&
            self.sqliteValue(
                from: model
                    ._fields
                    .first(
                        where: { $0.instanceKey == key }
                    )!
                    .wrappedValue as! V
            )
            .fieldIsBiggerThan(
                sqliteValue
                    .underlyingValue(
                        withTypeName: V.sqliteTypeName
                    ),
                withTypeName:
                    value.asPersistentRepresentation
                    .sqliteTypeName
            )
        }
        old.conditions = old.conditions && next
        old.hashValue = newHash(next, sqliteValue)
        return old
    }
    
    private func smaller<V: Persistable>(_ key: String,
                                        _ value: V) -> Self {
        let sqliteValue = sqliteValue(from: value)
        
        let next = V.sqliteTypeName.fieldIsSmallerToExpression(
            key: key,
            value: sqliteValue
                .underlyingValue(
                    withTypeName: V.sqliteTypeName
                )
        )
        var old = self
        old.checkMatching = { model in
            checkMatching(model) &&
            self.sqliteValue(
                from: model
                    ._fields
                    .first(
                        where: { $0.instanceKey == key }
                    )!
                    .wrappedValue as! V
            )
            .fieldIsSmallerThan(
                sqliteValue
                    .underlyingValue(
                        withTypeName: V.sqliteTypeName
                    ),
                withTypeName:
                    value.asPersistentRepresentation
                    .sqliteTypeName
            )
        }
        old.conditions = old.conditions && next
        old.hashValue = newHash(next, sqliteValue)
        return old
    }
    
    private func smallerOrEqual<V: Persistable>(_ key: String,
                                               _ value: V) -> Self {
        let sqliteValue = sqliteValue(from: value)
        
        let next = V.sqliteTypeName.fieldIsSmallerOrEqualToExpression(
            key: key,
            value: sqliteValue
                .underlyingValue(
                    withTypeName: V.sqliteTypeName
                )
        )
        var old = self
        old.checkMatching = { model in
            checkMatching(model) &&
            self.sqliteValue(
                from: model
                    ._fields
                    .first(
                        where: { $0.instanceKey == key }
                    )!
                    .wrappedValue as! V
            )
            .fieldIsSmallerOrEqual(
                sqliteValue
                    .underlyingValue(
                        withTypeName: V.sqliteTypeName
                    ),
                withTypeName:
                    value.asPersistentRepresentation
                    .sqliteTypeName
            )
        }
        old.conditions = old.conditions && next
        old.hashValue = newHash(next, sqliteValue)
        return old
    }
    
    private func biggerOrEqual<V: Persistable>(_ key: String,
                                              _ value: V) -> Self {
        let sqliteValue = sqliteValue(from: value)
        
        let next = V.sqliteTypeName.fieldIsBiggerOrEqualToExpression(
            key: key,
            value: sqliteValue
                .underlyingValue(
                    withTypeName: V.sqliteTypeName
                )
        )
        var old = self
        old.checkMatching = { model in
            checkMatching(model) &&
            self.sqliteValue(
                from: model
                    ._fields
                    .first(
                        where: { $0.instanceKey == key }
                    )!
                    .wrappedValue as! V
            )
            .fieldIsBiggerOrEqual(
                sqliteValue
                    .underlyingValue(
                        withTypeName: V.sqliteTypeName
                    ),
                withTypeName:
                    value.asPersistentRepresentation
                    .sqliteTypeName
            )
        }
        old.conditions = old.conditions && next
        old.hashValue = newHash(next, sqliteValue)
        return old
    }
    
    func finalize() -> Expression<Bool?> {
        return conditions
    }
    
    private func newHash(_ expression: Expression<Bool?>, _ value: SQLiteValue) -> Int {
        var hasher = Hasher()
        hasher.combine(hashValue)
        hasher.combine(expression.template.hashValue)
        value.hash(into: &hasher)
        return hasher.finalize()
    }
    
    private func sqliteValue<V: Persistable>(from value: V) -> SQLiteValue {
        value
            .asPersistentRepresentation
            .sqliteValue
    }
    
    public func doesMatch(_ model: T) -> Bool {
        checkMatching(model)
    }
}
