// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
// Licensed under Mozilla Public License v2.0
//
// See LICENSE.txt for license information
//
// ===----------------------------------------------------------------------===

import Atomics

protocol ObservationNotificationConfigurable {}

extension ObservationNotificationConfigurable {
    var callBeforeChange: Bool {
        ManagedObjectContext.callBeforeChange.load(ordering: .acquiring) == 1
    }
}

extension Field: ObservationNotificationConfigurable {}
extension LazyField: ObservationNotificationConfigurable {}
extension _OneRelationship: ObservationNotificationConfigurable {}
extension _ManyRelationship: ObservationNotificationConfigurable {}
extension ManagedObjectContext: ObservationNotificationConfigurable {}

extension ObservationNotificationConfigurable {
    func _withObservationNotification<R>(
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
