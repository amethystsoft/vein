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

import Foundation
import ULID

public struct _ReferenceCountedObservers: @unchecked Sendable {
    @_spi(VeinTesting) public var references = [ULID: Set<String>]()
    @_spi(VeinTesting) public var observers = [ULID: () -> Void]()

    public mutating func addObserver(id: ULID, key: String, observer: @escaping () -> Void) {
        references[id, default: []].insert(key)
        if observers[id].isNil { observers[id] = observer }
    }

    public mutating func removeObserver(id: ULID, key: String) {
        references[id, default: []].remove(key)
        if references[id]?.isEmpty == true {
            observers.removeValue(forKey: id)
            references.removeValue(forKey: id)
        }
    }

    public func notifyAll() {
        for observer in observers.values {
            observer()
        }
    }

    public init() {}
}
