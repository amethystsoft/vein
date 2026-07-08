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

import Foundation

/// A custom Mutex currently only intended for internal use.
///
/// It's based on NSLock.
///
/// Why not Synchronization.Mutex?: I have the goal of expanding the compatibility of vein in the future \
/// potentially including Swift versions not supported by Synchronization's Mutex.
public final class Mutex<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    public init(_ value: Value) {
        self._value = value
    }

    /// Use `set` only for blind overwrites.
    /// Changing arrays or dictionaries based on their
    /// current value must be done in ``Mutex/mutate(_:)``.
    public var value: Value {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }

    /// Mutate the content in a thread-safe way
    public func mutate<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        try lock.withLock{ try body(&_value) }
    }
}
