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

import Testing
@testable import Vein

@Suite
struct ULIDDerivability {
    @Test
    func `deriving`() async throws {
        let timestamp = Date(timeIntervalSince1970: 1793029207)
        let ulid = ULID(timestamp: timestamp)
        let derived = ulid.deriveNew()

        #expect(derived.timestamp == timestamp)

        try await Task.sleep(for: .milliseconds(100))

        let derivedAgain = ulid.deriveNew()

        #expect(derivedAgain == derived)

        let expected: ulid_t = (
            1,
            161,
            120,
            222,
            115,
            216,
            1,
            32,
            19,
            204,
            99,
            105,
            239,
            185,
            177,
            159
        )
        #expect(derived.ulid.0 == expected.0)
        #expect(derived.ulid.1 == expected.1)
        #expect(derived.ulid.2 == expected.2)
        #expect(derived.ulid.3 == expected.3)
        #expect(derived.ulid.4 == expected.4)
        #expect(derived.ulid.5 == expected.5)
        #expect(derived.ulid.6 == expected.6)
        #expect(derived.ulid.7 == expected.7)
        #expect(derived.ulid.8 == expected.8)
        #expect(derived.ulid.9 == expected.9)
        #expect(derived.ulid.10 == expected.10)
        #expect(derived.ulid.11 == expected.11)
        #expect(derived.ulid.12 == expected.12)
        #expect(derived.ulid.13 == expected.13)
        #expect(derived.ulid.14 == expected.14)
        #expect(derived.ulid.15 == expected.15)

        #expect(derivedAgain.ulid.0 == expected.0)
        #expect(derivedAgain.ulid.1 == expected.1)
        #expect(derivedAgain.ulid.2 == expected.2)
        #expect(derivedAgain.ulid.3 == expected.3)
        #expect(derivedAgain.ulid.4 == expected.4)
        #expect(derivedAgain.ulid.5 == expected.5)
        #expect(derivedAgain.ulid.6 == expected.6)
        #expect(derivedAgain.ulid.7 == expected.7)
        #expect(derivedAgain.ulid.8 == expected.8)
        #expect(derivedAgain.ulid.9 == expected.9)
        #expect(derivedAgain.ulid.10 == expected.10)
        #expect(derivedAgain.ulid.11 == expected.11)
        #expect(derivedAgain.ulid.12 == expected.12)
        #expect(derivedAgain.ulid.13 == expected.13)
        #expect(derivedAgain.ulid.14 == expected.14)
        #expect(derivedAgain.ulid.15 == expected.15)
    }
}
