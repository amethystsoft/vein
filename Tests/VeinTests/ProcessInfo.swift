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

extension ProcessInfo {
    static var shouldEnableEncryption: Bool {
        //ProcessInfo.processInfo.environment["SHOULD_DISABLE_ENCRYPTION"] != "1"
        // Currently encryption should be disabled for all tests, except test ignoring this flag.
        false
    }
    static var isRunningHeadless: Bool {
        ProcessInfo.processInfo.environment["IS_RUNNING_HEADLESS"] == "1"
    }
}
