// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import Foundation
import ULID

extension ULID {
    /// Derive a new ULID from the current ULID deterministically.
    /// The new ULID will sort near it's parent.
    ///
    /// Calling `deriveNew` multiple times on the same ULID will always give the exact same result.
    public func deriveNew() -> ULID {
        var generator = SeededRandomNumberGenerator(seed: self.last64Bits)
        return ULID(timestamp: self.timestamp, generator: &generator)
    }

    var last64Bits: UInt64 {
        [
            self.ulid.8,
            self.ulid.9,
            self.ulid.10,
            self.ulid.11,
            self.ulid.12,
            self.ulid.13,
            self.ulid.14,
            self.ulid.15
        ].reduce(0) { ($0 << 8) | UInt64($1) }
    }
}

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    // Splitmix
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
