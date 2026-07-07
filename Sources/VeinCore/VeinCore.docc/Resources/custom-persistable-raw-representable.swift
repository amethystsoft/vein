import VeinCore

enum AccountType: String, RawRepresentablePersistable {
    case admin
    case service
    case sales
    case user
}
