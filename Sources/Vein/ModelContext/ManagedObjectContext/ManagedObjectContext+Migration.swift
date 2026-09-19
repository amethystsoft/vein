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

import SQLiteDB
import Foundation

extension ManagedObjectContext {
    internal static var veinVersion: ModelVersion { ModelVersion(1, 1, 1) }
    internal nonisolated func createSystemTable() throws {
        try connection.run(SystemTable.systemTable.create(ifNotExists: true) { t in
            t.column(SystemTable.id, primaryKey: .autoincrement)
            t.column(SystemTable.veinVersionMajor)
            t.column(SystemTable.veinVersionMinor)
            t.column(SystemTable.veinVersionPatch)
            t.column(SystemTable.appliedAutoheals)
        })
        
        let version = Self.veinVersion
        if try _getSystemTable() == nil {
            let insert = SystemTable.systemTable.insert(
                [
                    SQLExpression<Int64>(SystemTable.veinVersionMajor)
                        <- SQLExpression<Int64>(value: Int64(version.major)),
                    SQLExpression<Int64>(SystemTable.veinVersionMinor)
                        <- SQLExpression<Int64>(value: Int64(version.minor)),
                    SQLExpression<Int64>(SystemTable.veinVersionPatch)
                        <- SQLExpression<Int64>(value: Int64(version.patch)),
                    SQLExpression<String>(SystemTable.appliedAutoheals)
                        <- SQLExpression<String>(value: "[]")
                ]
            )
            try connection.run(insert)
        } else {
            let update = SystemTable.systemTable.update(
                [
                    SQLExpression<Int64>(SystemTable.veinVersionMajor)
                    <- SQLExpression<Int64>(value: Int64(version.major)),
                    SQLExpression<Int64>(SystemTable.veinVersionMinor)
                    <- SQLExpression<Int64>(value: Int64(version.minor)),
                    SQLExpression<Int64>(SystemTable.veinVersionPatch)
                    <- SQLExpression<Int64>(value: Int64(version.patch))
                ]
            )
            try connection.run(update)
        }
    }
    
    public nonisolated func runAutoheal(_ heal: _Autoheal) throws {
        try heal.run(modelContainer)
    }
    
    internal nonisolated func _getSystemTable() throws -> SystemTable.DTO? {
        let select = SystemTable.systemTable.select([
            SystemTable.veinVersionMajor,
            SystemTable.veinVersionMinor,
            SystemTable.veinVersionPatch,
            SystemTable.appliedAutoheals
        ]).limit(1)
        
        let result = try connection.prepare(select)
        for row in result {
            let autoheals = row[SystemTable.appliedAutoheals]
            let decoded = try JSONDecoder().decode(
                [String].self,
                from: autoheals.data(using: .utf8)!
            )
            let dto = SystemTable.DTO(
                veinVersionMajor: row[SystemTable.veinVersionMajor],
                veinVersionMinor: row[SystemTable.veinVersionMinor],
                veinVersionPatch: row[SystemTable.veinVersionPatch],
                appliedAutheals: decoded
            )
            
            if ModelVersion(
                UInt32(dto.veinVersionMajor),
                UInt32(dto.veinVersionMinor),
                UInt32(dto.veinVersionPatch)
            ) > Self.veinVersion {
                throw MOCError.dbOpenedWithOlderVeinVersion
            }
            
            return dto
        }
        
        return nil
    }
    
    internal nonisolated func getSystemTable() throws -> SystemTable.DTO {
        do {
            return try _getSystemTable() ?? SystemTable.DTO(
                veinVersionMajor: Int64(Self.veinVersion.major),
                veinVersionMinor: Int64(Self.veinVersion.minor),
                veinVersionPatch: Int64(Self.veinVersion.patch),
                appliedAutheals: []
            )
        } catch let error as SQLiteDB.Result {
            let parsed = error.parse()
            
            if case .noSuchTable = parsed {
                if try _tableExists(for: MigrationTable.schema) {
                    return SystemTable.DTO(
                        veinVersionMajor: 1,
                        veinVersionMinor: 1,
                        veinVersionPatch: 0,
                        appliedAutheals: []
                    )
                } else {
                    let veinVersion = Self.veinVersion
                    return SystemTable.DTO(
                        veinVersionMajor: Int64(veinVersion.major),
                        veinVersionMinor: Int64(veinVersion.minor),
                        veinVersionPatch: Int64(veinVersion.patch),
                        appliedAutheals: []
                    )
                }
            }
            
            throw parsed
        }
    }
    
    internal nonisolated func createMigrationsTable() throws {
        try connection.run(MigrationTable.migrationsTable.create(ifNotExists: true) { t in
            t.column(MigrationTable.id, primaryKey: .autoincrement)
            t.column(MigrationTable.tableName)
            t.column(MigrationTable.major)
            t.column(MigrationTable.minor)
            t.column(MigrationTable.patch)
            t.column(MigrationTable.appliedAt)
        })
    }

    internal nonisolated func registerMigration(
        schema: String,
        version: ModelVersion
    ) throws {
        // swiftformat:disable wrap, wrapArguments
        let query = MigrationTable.migrationsTable
            .insert([
                SQLExpression<String>(MigrationTable.tableName) <- SQLExpression<String>(value: schema),
                SQLExpression<Int64>(MigrationTable.major) <- SQLExpression<Int64>(value: Int64(version.major)),
                SQLExpression<Int64>(MigrationTable.minor) <- SQLExpression<Int64>(value: Int64(version.minor)),
                SQLExpression<Int64>(MigrationTable.patch) <- SQLExpression<Int64>(value: Int64(version.patch)),
                SQLExpression<Int64>(MigrationTable.appliedAt) <- SQLExpression<Int64>(value: Int64(Date().timeIntervalSince1970))
            ])
        // swiftformat:enable wrap, wrapArguments
        try connection.run(query)
    }

    internal nonisolated func deleteTable(_ schema: String) throws {
        let query = Table(schema).drop(ifExists: true)
        try connection.run(query)
    }

    internal nonisolated func getLatestMigrationVersion() throws -> ModelVersion? {
        let query = MigrationTable.migrationsTable
            .select(MigrationTable.major, MigrationTable.minor, MigrationTable.patch)
            .order(MigrationTable.major.desc, MigrationTable.minor.desc, MigrationTable.patch.desc)
            .limit(1)

        guard let row = try connection.pluck(query) else {
            return nil
        }

        return ModelVersion(
            UInt32(row[MigrationTable.major]),
            UInt32(row[MigrationTable.minor]),
            UInt32(row[MigrationTable.patch])
        )
    }

    internal nonisolated func renameSchema(_ schema: String, to newName: String) throws {
        let query = Table(schema)
            .rename(Table(newName))
        try connection.run(query)
    }

    @MainActor
    package func cleanupOldSchema(_ schema: any VersionedSchema.Type) throws {
        guard isInActiveMigration.value else {
            throw ManagedObjectContextError
                .notInsideMigration("ManagedObjectContext/cleanupOldSchema")
        }
        for model in schema.models {
            try deleteTable(model.schema)
        }
    }

    @MainActor
    package func removeModelsFromContext(for schema: any VersionedSchema.Type) {
        for modelType in schema.models {
            let models = identityMap.getAll(of: modelType)
            models.forEach {
                $0.context = nil
            }
            identityMap.removeAll(of: modelType)
        }
    }
}

enum MigrationTable {
    static let schema = "_vein_migrations"
    static let migrationsTable = Table(schema)
    static let id = SQLExpression<Int64>("id")
    static let tableName = SQLExpression<String>("table_name")
    static let major = SQLExpression<Int64>("major")
    static let minor = SQLExpression<Int64>("minor")
    static let patch = SQLExpression<Int64>("patch")
    static let appliedAt = SQLExpression<Int64>("applied_at")
}

enum SystemTable {
    static let schema = "_vein_system"
    static let systemTable = Table(schema)
    static let id = SQLExpression<Int64>("id")
    static let veinVersionMajor = SQLExpression<Int64>("vein_version_major")
    static let veinVersionMinor = SQLExpression<Int64>("vein_version_minor")
    static let veinVersionPatch = SQLExpression<Int64>("vein_version_patch")
    static let appliedAutoheals = SQLExpression<String>("applied_autoheals")
    
    struct DTO {
        let veinVersionMajor: Int64
        let veinVersionMinor: Int64
        let veinVersionPatch: Int64
        let appliedAutheals: [String]
    }
}
