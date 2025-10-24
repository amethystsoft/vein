public protocol ManagedObjectProtocol: Identifiable {
    var isPersisted: Bool { get set }
    var context: ManagedObjectContext { get }
}
