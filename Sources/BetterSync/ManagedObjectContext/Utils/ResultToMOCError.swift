import SQLite
import SQLite3.Ext

package extension SQLite.Result {
    func parse() -> ManagedObjectContextError {
        return switch self {
            case .error(let message, let code, _):
                mapCode(code, msg: message)
            default:
                .other(self.localizedDescription)
        }
    }
    
    private func mapCode(_ code: Int32, msg: String) -> ManagedObjectContextError {
        switch code {
            case SQLITE_PERM:
                .insufficientPermissions(message: msg)
            case SQLITE_READONLY:
                .writeInReadonly(message: msg)
            case SQLITE_IOERR:
                .io(message: msg, code: code)
            default:
                .unknownSQLite(message: msg, code: code)
        }
    }
}
