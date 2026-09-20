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
protocol DiskUsingTest {
    var additionalPath: String { get }
}

extension DiskUsingTest {
    func prepareContainerLocation(name: String) throws -> String? {
        let containerPath = FileManager.default.temporaryDirectory

        let dbDir = containerPath.relativePath
            .appending("/veinTests/\(testID.uuidString)\(additionalPath)")

        let shouldRunInMemory = ProcessInfo.processInfo.environment["TestOnDisk"] == nil

        if shouldRunInMemory {
            return nil
        }

        let dbPath = dbDir.appending("/\(name).sqlite3")

        try FileManager.default.createDirectory(
            atPath: dbDir,
            withIntermediateDirectories: true
        )

        return dbPath
    }
}
