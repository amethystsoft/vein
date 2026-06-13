import Foundation
import SQLiteDB

fileprivate struct Test {
    var mio: String
    var mia: String
    var randomNumber: Int
}

extension Predicate {
    public func toSQLiteFilter() throws -> SQLExpression<Bool> {
        let rootExpression: any StandardPredicateExpression<Bool> = self.expression
        
        guard let sqliteExpression = openAndResolveRoot(rootExpression) else {
            throw NSError(domain: "SQLiteBuilderError", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Predicate root must evaluate to a Boolean filter expression."])
        }
        
        return sqliteExpression
    }
    
    private func openAndCastToFilter<T: SQLiteExpressibleBuilder>(_ builder: T) -> SQLExpression<Bool>? {
        let result = builder.asSQLiteExpression()
        print("result: \(type(of: result))")
        return result as? SQLExpression<Bool>
    }
    
    private func openAndResolveRoot<E: StandardPredicateExpression<Bool>>(_ expression: E) -> SQLExpression<Bool>? {
        // If the concrete underlying node conforms to SQLiteExpressibleBuilder, pass it to the next step
        if let builder = expression as? any SQLiteExpressibleBuilder {
            return openAndCastToFilter(builder)
        }
        return nil
    }
}

public protocol SQLiteExpressibleBuilder: PredicateExpression {
    associatedtype Representation: ColumnType
    func asSQLiteExpression() -> SQLExpression<Representation.SQLiteType>
}

extension PredicateExpressions.Variable: SQLiteExpressibleBuilder {
    public typealias Representation = Bool
    
    public func asSQLiteExpression() -> SQLExpression<Bool> {
        return SQLExpression<Bool>("")
    }
}

extension PredicateExpressions.Value: SQLiteExpressibleBuilder where Output: Persistable {
    public typealias Representation = Output.PersistentRepresentation
    public func asSQLiteExpression() -> SQLExpression<Representation.SQLiteType> {
        return self.value.asPersistentRepresentation.sqlExpression
    }
}

extension PredicateExpressions.KeyPath: SQLiteExpressibleBuilder where
    Root: SQLiteExpressibleBuilder,
    Output: Persistable
{
    public typealias Representation = Output.PersistentRepresentation
    
    public func asSQLiteExpression() -> SQLExpression<Representation.SQLiteType> {
        let columnName = String(String(describing: keyPath).split(separator: ".").last!)
        return SQLExpression<Representation.SQLiteType>(columnName)
    }
}

extension PredicateExpressions.Equal: SQLiteExpressibleBuilder where
    LHS: SQLiteExpressibleBuilder,
    RHS: SQLiteExpressibleBuilder,
    LHS.Output: Persistable,
    LHS.Output == RHS.Output,
    LHS.Representation == RHS.Representation,
    LHS.Representation.SQLiteType: SQLiteDB.Value,
    LHS.Representation.SQLiteType.Datatype: Equatable
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() -> SQLExpression<Representation.SQLiteType> {
        let left = self.lhs.asSQLiteExpression()
        let right = self.rhs.asSQLiteExpression()
        return SQLExpression<Bool.SQLiteType>(left == right)
    }
}

extension PredicateExpressions.Conjunction: SQLiteExpressibleBuilder where
    LHS: SQLiteExpressibleBuilder,
    RHS: SQLiteExpressibleBuilder,
    LHS.Output == Bool,
    RHS.Output == Bool,
    LHS.Representation == Bool,
    RHS.Representation == Bool
{
    public typealias Representation = Bool
    
    public func asSQLiteExpression() -> SQLExpression<Bool.SQLiteType> {
        let left = SQLExpression<Bool>(self.lhs.asSQLiteExpression())
        let right = SQLExpression<Bool>(self.rhs.asSQLiteExpression())
        
        return SQLExpression<Bool.SQLiteType>(left && right)
    }
}
