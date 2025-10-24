import SQLite
public enum UnderlayingFieldType {
    case uuid(required: Bool = false)
    case string(required: Bool = false)
    case int(required: Bool = false)
    case double(required: Bool = false)
    case bool(required: Bool = false)
    case data(required: Bool = false)
    case date(required: Bool = false)
    case url(required: Bool = false)
}

extension UnderlayingFieldType {
    func addColumn(to table: inout SQLite.TableBuilder, withName name: String) {
        switch self {
            case .uuid(let required), .string(let required), .date(let required), .url(let required):
                if required {
                    table.column(Expression<String>(name))
                } else {
                    table.column(Expression<String?>(name))
                }
            case .double(let required):
                if required {
                    table.column(Expression<Double>(name))
                } else {
                    table.column(Expression<Double?>(name))
                }
            case .bool(let required):
                if required {
                    table.column(Expression<Bool>(name))
                } else {
                    table.column(Expression<Bool?>(name))
                }
            case .int(let required):
                if required {
                    table.column(Expression<Int64>(name))
                } else {
                    table.column(Expression<Int64?>(name))
                }
            case .data(let required):
                if required {
                    table.column(Expression<SQLite.Blob>(name))
                } else {
                    table.column(Expression<SQLite.Blob?>(name))
                }
        }
    }
}
