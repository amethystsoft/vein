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
import Testing
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUI
#else
    @_spi(VeinTesting) @testable import VeinCore
#endif

protocol RelationshipIntegrityCheckHelper {}

extension RelationshipIntegrityCheckHelper {
    func check(
        _ schema: any VersionedSchema.Type,
        _ migration: any SchemaMigrationPlan.Type,
        setup: (ManagedObjectContext) throws -> Void,
        corrupt: (Connection) throws -> Void,
        validate: ([RelationshipIntegrityReport]) -> Void
    ) throws {
        let container = try ModelContainer(
            schema,
            migration: migration,
            at: nil,
            appID: "de.amethystsoft.vein.test.relationship-integrity-check",
            encryptionEnabled: false
        )

        try setup(container.context)
        try container.context.save()
        
        try corrupt(container.getConnection())

        let result = try container.context.checkRelationshipIntegrity()
        validate(result)
    }
}
