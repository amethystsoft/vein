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
import VeinCore

@MainActor
public struct MigrationTester {
    /// An error in the `SchemaMigrationPlan`
    public enum Error: Swift.Error {
        /// Schemas are not sorted oldest to newest.
        case schemasNotSorted
        /// Stages are not sorted oldest to newest or they contain a gap,
        /// where rhs start version is not equal to lhs destination version.
        ///
        /// Vein requires
        /// lhsStartSchema.version < rhsStartSchema.version AND
        /// lhsDestinationSchema == rhsStartSchema AND
        /// rhsDestinationSchema.version > rhsStartSchema.version
        case stagesNotSortedOrWithGaps
        /// A `SchemaMigrationPlan` is required to have at least one schema.
        case mustContainSchema
        /// The first migration stage must start at the first schema.
        case firstStageMustStartAtFirstSchema
        /// The last migration stage must end with the last schema.
        case lastStageMustEndWithLastSchema
        /// A stage uses a schema not part of schemas.
        case usesUnknownSchema(any VersionedSchema.Type, in: MigrationStage)
        /// There must be one less stage than there are schemas.
        case invalidNumberOfMigrationStages
        case _unknownStageType
    }

    private let migrationPlan: any SchemaMigrationPlan.Type
    private let id = UUID()
    public let containerPath: String

    public init(migrationPlan: any SchemaMigrationPlan.Type) throws {
        self.migrationPlan = migrationPlan

        guard migrationPlan.schemas.isSorted(by: { $0.version < $1.version }) else {
            throw Error.schemasNotSorted
        }

        guard migrationPlan.stages.isSorted(by: {
            guard
                case .complex(let lhsStartSchema, let lhsDestinationSchema, _, _) = $0,
                case .complex(let rhsStartSchema, let rhsDestinationSchema, _, _) = $1
            else { return false }

            return lhsStartSchema.version < rhsStartSchema.version
                && lhsDestinationSchema == rhsStartSchema
                && rhsDestinationSchema.version > rhsStartSchema.version
        }) else {
            throw Error.stagesNotSortedOrWithGaps
        }

        guard migrationPlan.schemas.count > 0 else {
            throw Error.mustContainSchema
        }

        guard migrationPlan.stages.count == migrationPlan.schemas.count - 1 else {
            throw Error.invalidNumberOfMigrationStages
        }

        if migrationPlan.schemas.count > 1 {
            guard
                let firstSchema = migrationPlan.schemas.first,
                case .complex(let startSchema, _, _, _) = migrationPlan.stages.first,
                firstSchema == startSchema
            else {
                throw Error.firstStageMustStartAtFirstSchema
            }

            guard
                let lastSchema = migrationPlan.schemas.last,
                case .complex(_, let endSchema, _, _) = migrationPlan.stages.last,
                lastSchema == endSchema
            else {
                throw Error.lastStageMustEndWithLastSchema
            }
        }

        for stage in migrationPlan.stages {
            guard case .complex(let startSchema, let endSchema, _, _) = stage else {
                throw Error._unknownStageType
            }
            guard migrationPlan.schemas.contains(where: { $0 == startSchema }) else {
                throw Error.usesUnknownSchema(startSchema, in: stage)
            }

            guard migrationPlan.schemas.contains(where: { $0 == endSchema }) else {
                throw Error.usesUnknownSchema(endSchema, in: stage)
            }
        }

        self.containerPath = try Self.prepareContainerLocation(
            plan: migrationPlan,
            id: id
        )
    }

    public func seed(
        version: VersionedSchema.Type,
        logConfiguration: LogConfiguration? = nil,
        with block: (ManagedObjectContext) throws -> Void
    ) throws {
        let container = try ModelContainer(
            version,
            migration: migrationPlan,
            at: containerPath,
            appID: "de.amethystsoft.vein.MigrationTests",
            encryptionEnabled: false,
            logConfiguration: logConfiguration
        )
        try block(container.context)
    }

    public func migrateAndCheck(
        version: VersionedSchema.Type,
        with block: (ManagedObjectContext) throws -> Void
    ) throws {
        let container = try ModelContainer(
            version,
            migration: migrationPlan,
            at: containerPath,
            appID: "de.amethystsoft.vein.MigrationTests",
            encryptionEnabled: false
        )
        try container.migrate()
        try block(container.context)
    }

    public func testCompleteChain(
        initialData: (ManagedObjectContext) throws -> Void,
        validations: [ModelVersion: (ManagedObjectContext) throws -> Void]
    ) throws {
        let schemas = migrationPlan.schemas
        guard
            let startingVersion = schemas.first
        else {
            throw ManagedObjectContextError
                .other(message: "\(migrationPlan) doesn't have any schemas")
        }

        let container = try ModelContainer(
            startingVersion,
            migration: migrationPlan,
            at: containerPath,
            appID: "de.amethystsoft.vein.MigrationTests",
            encryptionEnabled: false
        )

        try initialData(container.context)
        try validations[startingVersion.version]?(container.context)

        for schema in schemas.dropFirst() {
            let currentContainer = try ModelContainer(
                schema,
                migration: migrationPlan,
                at: containerPath,
                appID: "de.amethystsoft.vein.MigrationTests",
                encryptionEnabled: false
            )

            try currentContainer.migrate()
            try validations[schema.version]?(currentContainer.context)
        }
    }

    private static func prepareContainerLocation(
        plan: any SchemaMigrationPlan.Type,
        id: UUID
    ) throws -> String {
        let containerPath = FileManager.default.temporaryDirectory

        let dbDir = containerPath.relativePath
            .appending("/vein-migrationTests/\(plan)/\(id.uuidString)")

        let dbPath = dbDir.appending("/db.sqlite3")

        try FileManager.default.createDirectory(
            atPath: dbDir,
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: dbPath) {
            guard FileManager.default.createFile(
                atPath: dbPath,
                contents: nil
            ) else {
                throw ManagedObjectContextError.other(
                    message: "Failed to create database at \(dbPath)"
                )
            }
        }

        return dbPath
    }
}

fileprivate extension Array {
    func isSorted(by sorter: (_ lhs: Element, _ rhs: Element) -> Bool) -> Bool {
        guard
            var current = self.first,
            count >= 2
        else { return true }

        for element in self[1...] {
            guard sorter(current, element) else {
                return false
            }
            current = element
        }

        return true
    }
}

extension MigrationTester.Error: @MainActor Equatable {
    @MainActor
    public static func == (lhs: MigrationTester.Error, rhs: MigrationTester.Error) -> Bool {
        switch (lhs, rhs) {
            case (
            usesUnknownSchema(let lhsSchema, let lhsMigrationStage),
            usesUnknownSchema(let rhsSchema, let rhsMigrationStage)
        ):
                return lhsSchema == rhsSchema && lhsMigrationStage == rhsMigrationStage
            case
            (.schemasNotSorted, .schemasNotSorted),
            (.stagesNotSortedOrWithGaps, .stagesNotSortedOrWithGaps),
            (.mustContainSchema, .mustContainSchema),
            (.firstStageMustStartAtFirstSchema, .firstStageMustStartAtFirstSchema),
            (.lastStageMustEndWithLastSchema, .lastStageMustEndWithLastSchema),
            (.invalidNumberOfMigrationStages, .invalidNumberOfMigrationStages),
            (._unknownStageType, ._unknownStageType):
                return true
            default: return false
        }
    }
}

/// This conformance is not fully correct, it only checks the schemas.
/// Do not use this yourself.
extension MigrationStage: @MainActor Equatable {
    public static func == (lhs: Vein.MigrationStage, rhs: Vein.MigrationStage) -> Bool {
        switch (lhs, rhs) {
            case (
            .complex(let lhsStartSchema, let lhsEndSchema, _, _),
            .complex(let rhsStartSchema, let rhsEndSchema, _, _)
        ):
                return lhsStartSchema == rhsStartSchema && lhsEndSchema == rhsEndSchema
        }

    }
}
