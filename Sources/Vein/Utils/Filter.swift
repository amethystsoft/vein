#if VeinFilter
    import VeinFilter

    import SQLiteDB

/// An Error that occured while converting a Filter to an SQL query.
public enum FilterConversionError: Error {
    case incompatibleFilter
    case unexpectedComparisonOperator(FilterExpressions.ComparisonOperator)
    case missingFieldInformation(String)
    case unexpectedUnsupportedRelationship(String)
    case unsupportedContainsType(ContainsPart)
    case unsupportedStartsWithType(ContainsPart)
    case notOperatorRequiresBoolExpression
    
    public enum ContainsPart: Sendable{
        case base
        case parameter
    }
}

extension FilterConversionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .incompatibleFilter:
                "Incompatible predicate"
            case .unexpectedComparisonOperator(let comparisonOperator):
                "Unexpected comparison operator: \(comparisonOperator)"
            case .missingFieldInformation(let string):
                "Missing field information: \(string)"
            case .unexpectedUnsupportedRelationship(let string):
                "Unexpected unsupported relationship: \(string)"
            case .unsupportedContainsType(let containsPart):
                "Unsupported contains type: \(containsPart)"
            case .unsupportedStartsWithType(let containsPart):
                "Unsupported starts with type: \(containsPart)"
            case .notOperatorRequiresBoolExpression:
                "not operator requires bool expression"
        }
    }
}

extension Filter {
    public func toSQLiteFilter() -> SQLExpression<Bool> {
        let rootExpression: any StandardFilterExpression<Bool> = self.expression
        
        guard let sqliteExpression = try openAndResolveRoot(rootExpression) else {
            throw FilterConversionError.incompatibleFilter
        }
        
        return sqliteExpression
    }
    
    private func openAndCastToFilter<T: SQLiteExpressibleBuilder>(_ builder: T) throws(
        FilterConversionError
    ) -> SQLExpression<Bool>? {
        let result = try builder.asSQLiteExpression()
        return result as? SQLExpression<Bool>
    }
    
    private func openAndResolveRoot<E: StandardFilterExpression<
        Bool
    >>(_ expression: E) throws(FilterConversionError)
    -> SQLExpression<Bool>?
    {
        // If the concrete underlying node conforms to SQLiteExpressibleBuilder, pass it to the next step
        if let builder = expression as? any SQLiteExpressibleBuilder {
            return try openAndCastToFilter(builder)
        }
        return nil
    }
}

/// The protocol used to convert parts of a Filter to SQL.
///
/// You can add conformances yourself, but I would ask to contribute them back to improve the Filter experience for everyone.
public protocol SQLiteExpressibleBuilder: FilterExpression {
    associatedtype Representation: ColumnType
    func asSQLiteExpression() throws(FilterConversionError)
    -> SQLExpression<Representation.SQLiteType>
}

extension FilterExpressions.Variable: SQLiteExpressibleBuilder {
    public typealias Representation = Bool
    
    public func asSQLiteExpression() -> SQLExpression<Bool> {
        return SQLExpression<Bool>("")
    }
}

extension FilterExpressions.Value: SQLiteExpressibleBuilder where Output: Persistable {
    public typealias Representation = Output.PersistentRepresentation
    public func asSQLiteExpression() -> SQLExpression<Representation.SQLiteType> {
        return self.value.asPersistentRepresentation.sqlExpression
    }
}

extension FilterExpressions.KeyPath: SQLiteExpressibleBuilder where
Root: SQLiteExpressibleBuilder,
Root.Output: PersistentModel,
Output: Persistable
{
    public typealias Representation = Output.PersistentRepresentation
    
    public func asSQLiteExpression() throws(FilterConversionError)
    -> SQLExpression<Representation.SQLiteType>
    {
        guard let information = Root.Output._predicateInformation(for: keyPath) else {
            throw .missingFieldInformation("\(keyPath)")
        }
        guard information.relationshipToType == nil else {
            throw .unexpectedUnsupportedRelationship(
                "\(keyPath) is a relationship. Filtering by relationships is currently unsupported."
            )
        }
        return SQLExpression<Representation.SQLiteType>(information.key)
    }
}

extension FilterExpressions.Equal: SQLiteExpressibleBuilder where
LHS: SQLiteExpressibleBuilder,
RHS: SQLiteExpressibleBuilder,
LHS.Output: Persistable,
RHS.Output: Persistable
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() throws(FilterConversionError) -> SQLExpression<Bool> {
        let left = try self.lhs.asSQLiteExpression()
        let right = try self.rhs.asSQLiteExpression()
        
        if right.template == "NULL" {
            return SQLExpression<Bool>("(\(left.template) IS NULL)", left.bindings)
        } else if left.template == "NULL" {
            return SQLExpression<Bool>("(\(right.template) IS NULL)", right.bindings)
        }
        
        return SQLExpression<Bool>(
            "(\(left.template) = \(right.template))",
            left.bindings + right.bindings
        )
    }
}

extension FilterExpressions.NotEqual: SQLiteExpressibleBuilder where
LHS: SQLiteExpressibleBuilder,
RHS: SQLiteExpressibleBuilder,
LHS.Output: Persistable,
RHS.Output: Persistable
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() throws(FilterConversionError) -> SQLExpression<Bool> {
        let left = try self.lhs.asSQLiteExpression()
        let right = try self.rhs.asSQLiteExpression()
        
        if right.template == "NULL" {
            return SQLExpression<Bool>("(\(left.template) IS NOT NULL)", left.bindings)
        } else if left.template == "NULL" {
            return SQLExpression<Bool>("(\(right.template) IS NOT NULL)", right.bindings)
        }
        
        return SQLExpression<Bool>(
            "(\(left.template) != \(right.template))",
            left.bindings + right.bindings
        )
    }
}

extension FilterExpressions.Comparison: SQLiteExpressibleBuilder where
LHS: SQLiteExpressibleBuilder,
RHS: SQLiteExpressibleBuilder,
LHS.Output: Persistable,
LHS.Output == RHS.Output,
LHS.Representation == RHS.Representation,
LHS.Representation.SQLiteType: SQLiteDB.Value,
LHS.Representation.SQLiteType.Datatype: Comparable
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() throws(FilterConversionError) -> SQLExpression<Bool> {
        let left = try self.lhs.asSQLiteExpression()
        let right = try self.rhs.asSQLiteExpression()
        
        switch op {
            case .lessThan: return SQLExpression<Bool>(left < right)
            case .lessThanOrEqual: return SQLExpression<Bool>(left <= right)
            case .greaterThan: return SQLExpression<Bool>(left > right)
            case .greaterThanOrEqual: return SQLExpression<Bool>(left >= right)
            @unknown default:
                throw .unexpectedComparisonOperator(op)
        }
    }
}

extension FilterExpressions.UnaryMinus: SQLiteExpressibleBuilder where
Wrapped: SQLiteExpressibleBuilder,
Wrapped.Output: Persistable
{
    public typealias Representation = Wrapped.Output.PersistentRepresentation
    
    public func asSQLiteExpression() throws(FilterConversionError)
    -> SQLExpression<Representation.SQLiteType>
    {
        let value = try self.wrapped.asSQLiteExpression()
        return SQLExpression("(-\(value.template))", value.bindings)
    }
}

extension FilterExpressions.Negation: SQLiteExpressibleBuilder where
Wrapped: SQLiteExpressibleBuilder
{
    public typealias Representation = Wrapped.Output.PersistentRepresentation
    
    public func asSQLiteExpression() throws(FilterConversionError)
    -> SQLExpression<Representation.SQLiteType>
    {
        guard let value = try self.wrapped.asSQLiteExpression() as? SQLExpression<Bool> else {
            throw .notOperatorRequiresBoolExpression
        }
        return value == SQLExpression<Bool.SQLiteType>(value: false)
    }
}

extension FilterExpressions.Conjunction: SQLiteExpressibleBuilder where
LHS: SQLiteExpressibleBuilder,
RHS: SQLiteExpressibleBuilder,
LHS.Output == Bool,
RHS.Output == Bool,
LHS.Representation == Bool,
RHS.Representation == Bool
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() throws(FilterConversionError)
    -> SQLExpression<Bool.SQLiteType>
    {
        let left = try SQLExpression<Bool>(self.lhs.asSQLiteExpression())
        let right = try SQLExpression<Bool>(self.rhs.asSQLiteExpression())
        
        return SQLExpression<Bool.SQLiteType>(left && right)
    }
}

extension FilterExpressions.Disjunction: SQLiteExpressibleBuilder where
LHS: SQLiteExpressibleBuilder,
RHS: SQLiteExpressibleBuilder,
LHS.Output == Bool,
RHS.Output == Bool,
LHS.Representation == Bool,
RHS.Representation == Bool
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() throws(FilterConversionError)
    -> SQLExpression<Bool.SQLiteType>
    {
        let left = try SQLExpression<Bool>(self.lhs.asSQLiteExpression())
        let right = try SQLExpression<Bool>(self.rhs.asSQLiteExpression())
        
        return SQLExpression<Bool.SQLiteType>(left || right)
    }
}

extension FilterExpressions.NilLiteral: SQLiteExpressibleBuilder where
Wrapped: Persistable
{
    public typealias Representation = Wrapped?.PersistentRepresentation
    
    /// DO NOT USE, JUST EXISTS FOR CONFORMANCE
    public func asSQLiteExpression() throws(FilterConversionError)
    -> SQLExpression<Representation.SQLiteType>
    {
        .init(literal: "NULL")
    }
}

extension FilterExpressions.SequenceStartsWith: SQLiteExpressibleBuilder where
Base: SQLiteExpressibleBuilder,
Prefix: SQLiteExpressibleBuilder,
Base.Output == String,
Prefix.Output == Base.Output
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() throws(FilterConversionError) -> SQLExpression<Bool> {
        guard let base = try self.base.asSQLiteExpression() as? SQLExpression<String>
                else { throw .unsupportedStartsWithType(.base) }
        guard let other = try self.prefix.asSQLiteExpression() as? SQLExpression<String>
                else { throw .unsupportedStartsWithType(.parameter) }
        
        return SQLExpression<Bool>(
            "instr(\(base.template), \(other.template)) = 1",
            base.bindings + other.bindings
        )
    }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
extension FilterExpressions.StringLocalizedStandardContains: SQLiteExpressibleBuilder where
Root: SQLiteExpressibleBuilder,
Other: SQLiteExpressibleBuilder,
Root.Output == String,
Other.Output == Root.Output
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() throws(FilterConversionError) -> SQLExpression<Bool> {
        guard let base = try self.root.asSQLiteExpression() as? SQLExpression<String>
                else { throw .unsupportedContainsType(.base) }
        guard let other = try self.other.asSQLiteExpression() as? SQLExpression<String>
                else { throw .unsupportedContainsType(.parameter) }
        
        let lowerBase = base.template != "?" ? "lower(\(base.template))": "?"
        let lowerOther = other.template != "?" ? "lower(\(other.template))": "?"
        
        let lowerBindings: [(any SQLiteDB.Binding)?] = (base.bindings + other.bindings).map {
            if let string = $0 as? String {
                return string.lowercased()
            }
            return $0
        }
        
        return SQLExpression<Bool>("instr(\(lowerBase), \(lowerOther)) > 0", lowerBindings)
    }
}
#endif

extension FilterExpressions.CollectionContainsCollection: SQLiteExpressibleBuilder where
Base: SQLiteExpressibleBuilder,
Other: SQLiteExpressibleBuilder,
Base.Output == String,
Other.Output == Base.Output
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() throws(FilterConversionError) -> SQLExpression<Bool> {
        guard let base = try self.base.asSQLiteExpression() as? SQLExpression<String>
                else { throw .unsupportedContainsType(.base) }
        guard let other = try self.other.asSQLiteExpression() as? SQLExpression<String>
                else { throw .unsupportedContainsType(.parameter) }
        
        return SQLExpression<Bool>(
            "instr(\(base.template), \(other.template)) > 0",
            base.bindings + other.bindings
        )
    }
}

#endif
