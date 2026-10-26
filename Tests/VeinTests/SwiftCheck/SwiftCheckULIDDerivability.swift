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

#if canImport(SwiftCheck)
    import SwiftCheck
    import Foundation
    import XCTest
    @testable import Vein

    class SwiftCheckULIDDerivability: XCTestCase {
        func testULIDDerivability() {
            property(
                "ULID derives always correctly"
            ) <- forAll { (date: FakeDate) in
                let ulid = ULID(timestamp: date.date)

                let derived = ulid.deriveNew()
                let derivedAgain = ulid.deriveNew()

                return derivedAgain == derived
                    && derived.ulidString.prefix(10) == derivedAgain.ulidString.prefix(10)
                    && derived.ulidString.prefix(9) == ulid.ulidString.prefix(9)
                    && abs(
                        derived.timestamp.timeIntervalSince1970
                            - ulid.timestamp.timeIntervalSince1970
                    ) < 1
                    && !derived.ulidString.hasPrefix("0000000000")
            }
        }
    }

    struct FakeDate {
        let date: Date
    }

    extension FakeDate: Arbitrary {
        static var arbitrary: SwiftCheck.Gen<FakeDate> {
            let doubleGen = Gen<Double>.choose((1, 32503736407))
            return Gen<FakeDate>.compose { gen in
                FakeDate(date: Date(timeIntervalSince1970: gen.generate(using: doubleGen)))
            }
        }
    }

#endif
