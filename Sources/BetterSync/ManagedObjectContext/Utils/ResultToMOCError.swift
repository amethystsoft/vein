import SQLite

package extension SQLite.Result {
    func parse() -> ManagedObjectContextError {
        return switch self {
            case .error(let message, let code, _):
                mapCode(code, msg: message)
            default:
                .other(message: self.localizedDescription)
        }
    }
    
    private func mapCode(_ code: Int32, msg: String) -> ManagedObjectContextError {
        switch code {
            case 3: //PERM
                .insufficientPermissions(message: msg)
            case 8: //READONLY
                .writeInReadonly(message: msg)
            case 10: //IOERR
                .io(message: msg, code: code)
            default:
                .unknownSQLite(message: msg, code: code)
        }
    }
}
