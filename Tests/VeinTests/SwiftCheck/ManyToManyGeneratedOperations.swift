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
    #if TEST_SWIFTUI
        @_spi(VeinTesting) @testable import VeinSwiftUI
    #elseif TEST_SCUI
        @_spi(VeinTesting) @testable import VeinSCUI
    #else
        @_spi(VeinTesting) @testable import VeinCore
    #endif

#endif
