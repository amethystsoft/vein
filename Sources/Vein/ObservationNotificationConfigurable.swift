// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
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
