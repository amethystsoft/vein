import Atomics
public protocol ObservationNotificationConfigurable {}

extension ObservationNotificationConfigurable {
    public var callBeforeChange: Bool {
        ManagedObjectContext.callBeforeChange.load(ordering: .relaxed) == 1
    }
}

extension Field: ObservationNotificationConfigurable {}
extension LazyField: ObservationNotificationConfigurable {}
extension _OneRelationship: ObservationNotificationConfigurable {}
extension _ManyRelationship: ObservationNotificationConfigurable {}
extension ManagedObjectContext: ObservationNotificationConfigurable {}

extension ObservationNotificationConfigurable {
    func withObservationNotification<R>(
        _ notification: () -> Void,
        block: () -> R
    ) -> R {
        if callBeforeChange {
            notification()
        }
        defer {
            if !callBeforeChange {
                notification()
            }
        }
        return block()
    }
}
