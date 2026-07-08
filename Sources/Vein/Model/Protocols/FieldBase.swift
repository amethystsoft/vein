import Foundation
import SQLiteDB

/// This is mostly an implementation detail, currently making your own fields is not supported.
public protocol FieldBase {
    associatedtype WrappedType: Persistable
    static var sqliteTypeName: SQLiteTypeName { get }
    var _key: String? { get set }
    var _model: (any PersistentModel)? { get set }
    func _setStoreToCapturedState(_ state: Any)
    var isLazy: Bool { get }
    var wasTouched: Bool { get }

    var _persistableValue: WrappedType { get set }
}

extension FieldBase {
    var key: String? {
        get {
            _key
        }

        set {
            _key = newValue
        }
    }

    weak var model: (any PersistentModel)? {
        get {
            _model
        }
        set {
            _model = newValue
        }
    }

    var persistableValue: WrappedType {
        get {
            _persistableValue
        }
        set {
            _persistableValue = newValue
        }
    }

    var instanceKey: String {
        guard let key else {
            fatalError(MOCError
                .keyMissing(message: "raised by Field property of Type '\(WrappedType.self)'")
                .localizedDescription)
        }
        return key
    }

    public static var sqliteTypeName: SQLiteTypeName {
        WrappedType.sqliteTypeName
    }

    var instanceObjectID: ObjectIdentifier {
        guard let _model else {
            fatalError(MOCError
                .modelReference(message: "raised by Field property of Type '\(WrappedType.self)'")
                .localizedDescription)
        }
        return _model.typeIdentifier
    }

    var instanceSchema: String {
        guard let _model else {
            fatalError(MOCError
                .modelReference(message: "raised by Field property of Type '\(WrappedType.self)'")
                .localizedDescription)
        }
        return _model._getSchema()
    }

    var instanceID: ULID {
        guard let _model else {
            fatalError(MOCError
                .modelReference(message: "raised by Field property of Type '\(WrappedType.self)'")
                .localizedDescription)
        }
        return _model.id
    }

    /// This expressible should only be used for fetching.
    ///
    /// It converts a JSONB column back to a json string.
    /// JSONB is proprietary, so we can't just use JSONDecoder with Data.
    /// To use a JSONB column, use "json(\"\(key)\")" on the row.
    /// SQLite.swift appears to do it that way.
    var fetchExpressible: Expressible {
        return switch Self.sqliteTypeName.isNull {
            case true:
                switch SQLiteTypeName.notNull(Self.sqliteTypeName){
                    case .integer: SQLExpression<Int64?>(instanceKey)
                    case .real: SQLExpression<Double?>(instanceKey)
                    case .text: SQLExpression<String?>(instanceKey)
                    case .blob: SQLExpression<Data?>(instanceKey)
                    case .jsonb: SQLExpression<String?>(literal: "json(\"\(instanceKey)\")")
                    default: fatalError()
                }
            case false:
                switch Self.sqliteTypeName {
                    case .integer: SQLExpression<Int64>(instanceKey)
                    case .real: SQLExpression<Double>(instanceKey)
                    case .text: SQLExpression<String>(instanceKey)
                    case .blob: SQLExpression<Data>(instanceKey)
                    case .jsonb: SQLExpression<String>(literal: "json(\"\(instanceKey)\")")
                    default: fatalError()
                }
        }
    }

    func decode(_ row: SQLiteDB.Row) -> WrappedType.PersistentRepresentation {
        do {
            let typeName = WrappedType.sqliteTypeName

            switch typeName {
                case .integer:
                    let value = row[SQLExpression<Int64>(instanceKey)]
                    return try WrappedType.PersistentRepresentation
                        .decode(sqliteValue: .integer(value))
                case .real:
                    let value = row[SQLExpression<Double>(instanceKey)]
                    return try WrappedType.PersistentRepresentation
                        .decode(sqliteValue: .real(value))
                case .text:
                    let value = row[SQLExpression<String>(instanceKey)]
                    return try WrappedType.PersistentRepresentation
                        .decode(sqliteValue: .text(value))
                case .blob:
                    let value = row[SQLExpression<Data>(instanceKey)]
                    return try WrappedType.PersistentRepresentation
                        .decode(sqliteValue: .blob(value))
                case .jsonb:
                    let value = row[SQLExpression<String>(literal: "json(\"\(instanceKey)\")")]
                    return try WrappedType.PersistentRepresentation
                        .decode(sqliteValue: .text(value))
                case .null:
                    switch SQLiteTypeName.notNull(typeName) {
                        case .integer:
                            let value = row[SQLExpression<Int64?>(instanceKey)]
                            if let value {
                                return try WrappedType.PersistentRepresentation
                                    .decode(sqliteValue: .integer(value))
                            }
                            return try WrappedType.PersistentRepresentation
                                .decode(sqliteValue: .null)
                        case .real:
                            let value = row[SQLExpression<Double?>(instanceKey)]
                            if let value {
                                return try WrappedType.PersistentRepresentation
                                    .decode(sqliteValue: .real(value))
                            }
                            return try WrappedType.PersistentRepresentation
                                .decode(sqliteValue: .null)
                        case .text:
                            let value = row[SQLExpression<String?>(instanceKey)]
                            if let value {
                                return try WrappedType.PersistentRepresentation
                                    .decode(sqliteValue: .text(value))
                            }
                            return try WrappedType.PersistentRepresentation
                                .decode(sqliteValue: .null)
                        case .blob:
                            let value = row[SQLExpression<Data?>(instanceKey)]
                            if let value {
                                return try WrappedType.PersistentRepresentation
                                    .decode(sqliteValue: .blob(value))
                            }
                            return try WrappedType.PersistentRepresentation
                                .decode(sqliteValue: .null)
                        case .jsonb:
                            let value =
                                row[SQLExpression<String?>(literal: "json(\"\(instanceKey)\")")]
                            if let value {
                                return try WrappedType.PersistentRepresentation
                                    .decode(sqliteValue: .text(value))
                            }
                            return try WrappedType.PersistentRepresentation
                                .decode(sqliteValue: .null)
                        default:
                            fatalError("unexpectedly received SQLiteTypeName of null")
                    }
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func asDTO() -> PersistedFieldDTO {
        PersistedFieldDTO(
            key: instanceKey,
            id: instanceID,
            schema: instanceSchema,
            sqliteType: persistableValue.asPersistentRepresentation.sqliteTypeName,
            enclosingObjectID: instanceObjectID
        )
    }

    func migrate(on builder: inout Vein.TableBuilder) {
        let required = !WrappedType.sqliteTypeName.isNull

        builder = switch SQLiteTypeName.notNull(WrappedType.sqliteTypeName) {
            case .integer:
                builder.field(instanceKey, type: .int(required: required))
            case .real:
                builder.field(instanceKey, type: .double(required: required))
            case .text:
                builder.field(instanceKey, type: .string(required: required))
            case .blob, .jsonb:
                builder.field(instanceKey, type: .data(required: required))
            case .null:
                fatalError(
                    "Unexpectedly hit null SQLiteTypeName while building migration on Field \(key ?? instanceKey)"
                )
        }
    }
}
