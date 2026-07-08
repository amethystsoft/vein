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

import VeinCore

enum ComplexMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [V0_0_1.self, V0_0_2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.complex(
        fromVersion: V0_0_1.self,
        toVersion: V0_0_2.self,
        willMigrate: { context in
            // 1. Fetch current models from the V1 database setup
            let oldTests = try context.fetchAll(V0_0_1.Test.self)

            // 2. Map old entries to new types individually
            for test in oldTests {
                let sanitizedValue = max(0, test.randomValue)

                let newTest = V0_0_2.Test(
                    flag: test.flag,
                    someValue: test.someValue,
                    securityCode: "SEC-\(sanitizedValue)"
                )

                // Add the new instance and remove the old one.
                // If a migration has unhandled non-empty tables at the end it will fail.
                try context.insert(newTest)
                try context.delete(test)
            }
        },
        didMigrate: nil
    )
}
