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
import Testing
@testable import VeinTesting
import Vein
#if TEST_SWIFTUI
    import VeinSwiftUI
#elseif !TEST_SWIFTUI
    import VeinCore
#endif

@MainActor
struct MigrationVerification {
    @Test
    func unsortedSchemasThrows() async throws {
        do {
            _ = try MigrationTester(migrationPlan: UnsortedSchemasPlan.self)
        } catch let error as MigrationTester.Error {
            #expect(error == MigrationTester.Error.schemasNotSorted)
            return
        }
        Issue.record("Unexpectedly no error was thrown.")
    }

    @Test
    func unsortedStagesThrows() async throws {
        do {
            _ = try MigrationTester(migrationPlan: UnsortedStagesPlan.self)
        } catch let error as MigrationTester.Error {
            #expect(error == MigrationTester.Error.stagesNotSortedOrWithGaps)
            return
        }
        Issue.record("Unexpectedly no error was thrown.")
    }

    @Test
    func gappedStagesThrows() async throws {
        do {
            _ = try MigrationTester(migrationPlan: GappedStagesPlan.self)
        } catch let error as MigrationTester.Error {
            #expect(error == MigrationTester.Error.stagesNotSortedOrWithGaps)
            return
        }
        Issue.record("Unexpectedly no error was thrown.")
    }

    @Test
    func noSchemaThrows() async throws {
        do {
            _ = try MigrationTester(migrationPlan: NoSchemaPlan.self)
        } catch let error as MigrationTester.Error {
            #expect(error == MigrationTester.Error.mustContainSchema)
            return
        }
        Issue.record("Unexpectedly no error was thrown.")
    }

    @Test
    func firstStageMustStartAtFirstSchemaThrows() async throws {
        do {
            _ = try MigrationTester(migrationPlan: FirstStageNotStartingAtFirstSchema.self)
        } catch let error as MigrationTester.Error {
            #expect(error == MigrationTester.Error.firstStageMustStartAtFirstSchema)
            return
        }
        Issue.record("Unexpectedly no error was thrown.")
    }

    @Test
    func lastStageMustEndAtLastSchemaThrows() async throws {
        do {
            _ = try MigrationTester(migrationPlan: LastStageNotEndingAtLastSchema.self)
        } catch let error as MigrationTester.Error {
            #expect(error == MigrationTester.Error.lastStageMustEndWithLastSchema)
            return
        }
        Issue.record("Unexpectedly no error was thrown.")
    }

    @Test
    func usesUnknownSchemaThrows() async throws {
        do {
            _ = try MigrationTester(migrationPlan: UsesUnknownSchema.self)
        } catch let error as MigrationTester.Error {
            let migrationStage = Vein.MigrationStage.complex(
                fromVersion: Version0.self,
                toVersion: Version1.self,
                willMigrate: nil,
                didMigrate: nil
            )
            #expect(
                error == MigrationTester.Error.usesUnknownSchema(
                    Version1.self,
                    in: migrationStage
                )
            )
            return
        }
        Issue.record("Unexpectedly no error was thrown.")
    }

    @Test
    func invalidNumberOfMigrationStagesThrows() async throws {
        do {
            _ = try MigrationTester(migrationPlan: InvalidNumberOfStages.self)
        } catch let error as MigrationTester.Error {
            #expect(error == MigrationTester.Error.invalidNumberOfMigrationStages)
            return
        }
        Issue.record("Unexpectedly no error was thrown.")
    }
}

fileprivate enum Version0: VersionedSchema {
    static let version = ModelVersion(0, 9, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self
    ]}

    @Model
    final class User {}
}

fileprivate enum Version1: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self
    ]}

    @Model
    final class User {}
}

fileprivate enum Version2: VersionedSchema {
    static let version = ModelVersion(1, 1, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self
    ]}

    @Model
    final class User {}
}

fileprivate enum Version3: VersionedSchema {
    static let version = ModelVersion(1, 2, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self
    ]}

    @Model
    final class User {}
}

fileprivate enum Version4: VersionedSchema {
    static let version = ModelVersion(1, 3, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self
    ]}

    @Model
    final class User {}
}

fileprivate enum Version5: VersionedSchema {
    static let version = ModelVersion(1, 4, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self
    ]}

    @Model
    final class User {}
}

fileprivate enum UnsortedSchemasPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self,
        Version2.self,
        Version4.self,
        Version3.self
    ]}

    static var stages: [Vein.MigrationStage] {[
        v1ToV2,
        v2ToV3,
        v3ToV4
    ]}

    static let v1ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version1.self,
        toVersion: Version2.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v2ToV3 = Vein.MigrationStage.complex(
        fromVersion: Version2.self,
        toVersion: Version3.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v3ToV4 = Vein.MigrationStage.complex(
        fromVersion: Version3.self,
        toVersion: Version4.self,
        willMigrate: nil,
        didMigrate: nil
    )
}

fileprivate enum UnsortedStagesPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self,
        Version2.self,
        Version3.self,
        Version4.self,
    ]}

    static var stages: [Vein.MigrationStage] {[
        v1ToV2,
        v3ToV4,
        v2ToV3,
    ]}

    static let v1ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version1.self,
        toVersion: Version2.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v2ToV3 = Vein.MigrationStage.complex(
        fromVersion: Version2.self,
        toVersion: Version3.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v3ToV4 = Vein.MigrationStage.complex(
        fromVersion: Version3.self,
        toVersion: Version4.self,
        willMigrate: nil,
        didMigrate: nil
    )
}

fileprivate enum GappedStagesPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self,
        Version2.self,
        Version3.self,
        Version4.self,
    ]}

    static var stages: [Vein.MigrationStage] {[
        v1ToV2,
        v3ToV4,
    ]}

    static let v1ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version1.self,
        toVersion: Version2.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v3ToV4 = Vein.MigrationStage.complex(
        fromVersion: Version3.self,
        toVersion: Version4.self,
        willMigrate: nil,
        didMigrate: nil
    )
}

fileprivate enum NoSchemaPlan: SchemaMigrationPlan {
    static let schemas: [any Vein.VersionedSchema.Type] = []
    static var stages: [Vein.MigrationStage] = []
}

fileprivate enum FirstStageNotStartingAtFirstSchema: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self,
        Version2.self,
        Version3.self,
        Version4.self,
    ]}

    static var stages: [Vein.MigrationStage] {[
        v0ToV2,
        v2ToV3,
        v3ToV4,
    ]}

    static let v0ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version0.self,
        toVersion: Version2.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v2ToV3 = Vein.MigrationStage.complex(
        fromVersion: Version2.self,
        toVersion: Version3.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v3ToV4 = Vein.MigrationStage.complex(
        fromVersion: Version3.self,
        toVersion: Version4.self,
        willMigrate: nil,
        didMigrate: nil
    )
}

fileprivate enum LastStageNotEndingAtLastSchema: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self,
        Version2.self,
        Version3.self,
        Version4.self,
    ]}

    static var stages: [Vein.MigrationStage] {[
        v1ToV2,
        v2ToV3,
        v3ToV5
    ]}

    static let v1ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version1.self,
        toVersion: Version2.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v2ToV3 = Vein.MigrationStage.complex(
        fromVersion: Version2.self,
        toVersion: Version3.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v3ToV5 = Vein.MigrationStage.complex(
        fromVersion: Version3.self,
        toVersion: Version5.self,
        willMigrate: nil,
        didMigrate: nil
    )
}

fileprivate enum UsesUnknownSchema: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version0.self,
        Version2.self,
        Version3.self,
        Version4.self,
    ]}

    static var stages: [Vein.MigrationStage] {[
        v0ToV1,
        v1ToV3,
        v3ToV4,
    ]}

    static let v0ToV1 = Vein.MigrationStage.complex(
        fromVersion: Version0.self,
        toVersion: Version1.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v1ToV3 = Vein.MigrationStage.complex(
        fromVersion: Version1.self,
        toVersion: Version3.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static let v3ToV4 = Vein.MigrationStage.complex(
        fromVersion: Version3.self,
        toVersion: Version4.self,
        willMigrate: nil,
        didMigrate: nil
    )
}

fileprivate enum InvalidNumberOfStages: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version0.self,
        Version2.self,
    ]}

    static var stages: [Vein.MigrationStage] {[]}
}
