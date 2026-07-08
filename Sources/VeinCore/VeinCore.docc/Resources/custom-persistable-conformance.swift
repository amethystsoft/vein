import VeinCore

extension Date: Persistable {
    public typealias PersistentRepresentation = Double

    public var asPersistentRepresentation: Double { self.timeIntervalSince1970 }

    public init?(fromPersistent representation: PersistentRepresentation) {
        self = Date(timeIntervalSince1970: representation)
    }
}
