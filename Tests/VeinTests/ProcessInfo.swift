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

extension ProcessInfo {
    static var shouldEnableEncryption: Bool {
        ProcessInfo.processInfo.environment["SHOULD_DISABLE_ENCRYPTION"] != "1"
    }
    static var isRunningHeadless: Bool {
        ProcessInfo.processInfo.environment["IS_RUNNING_HEADLESS"] == "1"
    }
}
