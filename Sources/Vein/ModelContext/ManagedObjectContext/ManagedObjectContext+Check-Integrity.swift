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

import ULID
import SQLiteDB

extension ManagedObjectContext {
    nonisolated func _checkRelationshipIntegrity<Model: PersistentModel>(
        of model: Model.Type,
        _ removingStaleReferences: Bool
    ) throws (MOCError) -> RelationshipIntegrityReport {
        guard modelContainer.versionedSchema.models.contains(where: {
            ObjectIdentifier($0) == ObjectIdentifier(model)
        }) else {
            throw MOCError.inactiveModelTypeFetched(model)
        }

        let relationships = model._fieldInformation.filter {
            $0.relationshipToType != nil
        }
        let idExpr = SQLExpression<String>("id")

        if relationships.isEmpty {
            return RelationshipIntegrityReport(schema: model.schema, models: [])
        }

        var models = [RelationshipIntegrityReport.Model]()

        var fieldsToLoad = relationships.map(\.fetchExpressible)
        fieldsToLoad.append(idExpr)
        let request = Table(model.schema).select(fieldsToLoad)

        do {
            let result = try connection.prepare(request)
            let (inverses, inverseInformation) = relationships.inverseMaps(for: model)

            for row in result {
                let idStr = row[idExpr]
                let (localMismatches, inverseMismatches) = try relationships.checkIntegrity(
                    idStr: idStr,
                    type: model,
                    connection: connection,
                    row: row,
                    inverses: inverses,
                    inverseInformation: inverseInformation,
                    removingStaleReferences: removingStaleReferences
                )

                if !localMismatches.isEmpty || !inverseMismatches.isEmpty {
                    models.append(
                        RelationshipIntegrityReport.Model(
                            idString: idStr,
                            localMismatches: localMismatches,
                            inverseMismatches: inverseMismatches
                        )
                    )
                }
            }
        } catch let error as SQLiteDB.Result {
            let parsed = error.parse()
            if case .noSuchTable = parsed {
                return RelationshipIntegrityReport(schema: model.schema, models: [])
            }
            throw parsed
        } catch {
            throw .other(message: error.localizedDescription)
        }

        return RelationshipIntegrityReport(
            schema: model.schema,
            models: models
        )
    }

    /// Checks the plausibility for all relationships of a row for each row for all schemas this context manages.
    ///
    /// - Parameters:
    ///   - removingStaleReferences: Whether to remove stale relationship references in the process.
    ///
    /// Saves will be locked while running the integrity check.
    public nonisolated func checkRelationshipIntegrity(
        removingStaleReferences: Bool = false
    ) throws(MOCError) -> [RelationshipIntegrityReport] {
        try checkRelationshipIntegrity(
            for: modelContainer.versionedSchema.models,
            removingStaleReferences: removingStaleReferences
        )
    }

    /// Checks the plausibility for all relationships of a row for each row for all specified schemas.
    ///
    /// - Parameters:
    ///   - models: The model types to check integrity of.
    ///   - removingStaleReferences: Whether to remove stale relationship references in the process.
    ///
    /// Saves will be locked while running the integrity check.
    public nonisolated func checkRelationshipIntegrity(
        for models: [any PersistentModel.Type],
        removingStaleReferences: Bool = false
    ) throws(MOCError) -> [RelationshipIntegrityReport] {
        saveLock.lock()
        defer {
            saveLock.unlock()
        }
        var reports = [RelationshipIntegrityReport]()
        do {
            for model in models {
                if removingStaleReferences {
                    try transaction {
                        try reports.append(
                            self._checkRelationshipIntegrity(of: model, removingStaleReferences)
                        )
                    }
                } else {
                    try reports.append(_checkRelationshipIntegrity(
                        of: model,
                        removingStaleReferences
                    ))
                }
            }
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch let error as ManagedObjectContextError {
            throw error
        } catch {
            throw ManagedObjectContextError.other(message: error.localizedDescription)
        }
        return reports
    }

    /// Checks the plausibility for all relationships of a row for each row currently in the specified table.
    ///
    /// - Parameters:
    ///   - model: The model type to check integrity of.
    ///   - removingStaleReferences: Whether to remove stale relationship references in the process.
    ///
    /// Saves will be locked while running the integrity check.
    public nonisolated func checkRelationshipIntegrity<Model: PersistentModel>(
        of model: Model.Type,
        removingStaleReferences: Bool = false
    ) throws(MOCError) -> RelationshipIntegrityReport {
        saveLock.lock()
        defer {
            saveLock.unlock()
        }
        do {
            if removingStaleReferences {
                var result: RelationshipIntegrityReport? = nil
                try transaction {
                    result = try self._checkRelationshipIntegrity(
                        of: model,
                        removingStaleReferences
                    )
                }
                return result!
            }
            return try _checkRelationshipIntegrity(of: model, removingStaleReferences)
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch let error as ManagedObjectContextError {
            throw error
        } catch {
            throw ManagedObjectContextError.other(message: error.localizedDescription)
        }
    }
}

extension [FieldInformation] {
    func inverseMaps<M: PersistentModel>(
        for model: M.Type
    ) -> ([String: String], [String: FieldInformation]) {
        var inverses = [String: String]()
        var inverseInformation = [String: FieldInformation]()

        for inverse in model._inverseFields.values {
            for (key, value) in inverse {
                // Safe under the assumption that the information is macro generated
                // and the generated information is correct.
                inverses[value] = key
            }
        }

        for information in self {
            guard let oppositeType = information.relationshipToType else { continue }
            if
                let inversesToThis = oppositeType._inverseFields[model.typeIdentifier],
                let key = inversesToThis[information.key]
            { inverses[information.key] = key }

            if let inverse = inverses[information.key] {
                inverseInformation[information.key] = oppositeType._fieldInformation.first {
                    $0.key == inverse
                }
            }
        }

        return (inverses, inverseInformation)
    }

    fileprivate func checkIntegrity<Model: PersistentModel>(
        idStr: String,
        type: Model.Type,
        connection: SQLiteDB.Connection,
        row: SQLiteDB.Row,
        inverses: [String: String],
        inverseInformation: [String: FieldInformation],
        removingStaleReferences: Bool
    ) throws -> (
        localMismatches: [String: RelationshipIntegrityReport.Mismatch],
        inverseMismatches: [String: [String: RelationshipIntegrityReport.Mismatch]]
    ) {
        var localMismatches = [String: RelationshipIntegrityReport.Mismatch]()
        var inverseMismatches = [String: [String: RelationshipIntegrityReport.Mismatch]]()
        let idExpr = SQLExpression<String>("id")

        if ULID(ulidString: idStr) == nil {
            localMismatches["id"] = .corruptedData
        }

        var setters = [Setter]()

        for relationship in self {
            let value = SQLiteValue(
                typeName: relationship.typeName,
                key: relationship.key,
                row: row
            )

            if case .null = value {
                continue
            }

            guard case .text(let string) = value else {
                localMismatches[relationship.key] = .unexpectedlyNotRelationship
                continue
            }

            let inverseInformation = inverseInformation[relationship.key]
            let fieldsToFetch: [Expressible]
            if let inverseInformation {
                fieldsToFetch = [idExpr, inverseInformation.fetchExpressible]
            } else {
                fieldsToFetch = [idExpr]
            }

            if relationship.relationshipType == .many,
               let ulids = [ULID](fromPersistent: SQLiteJSONB(jsonString: string))
            {
                let uniqued = Set(ulids)
                var stringArray = uniqued.map(\.ulidString)
                let query = Table(relationship.relationshipToType!.schema)
                    .select(fieldsToFetch)
                    .where(stringArray.contains(idExpr))

                var rows: AnySequence<Row>
                do {
                    rows = try connection.prepare(query)
                } catch let error as SQLiteDB.Result {
                    let parsed = error.parse()
                    if case .noSuchTable = parsed {
                        if !removingStaleReferences {
                            for ulid in ulids {
                                inverseMismatches[
                                    relationship.key,
                                    default: [:]
                                ][ulid.ulidString] = .missingInInverse
                            }
                        } else {
                            setters.append(
                                SQLiteJSONB(jsonString: "[]").sqliteSetter(key: relationship.key)
                            )
                        }
                        continue
                    }
                    throw error
                }

                for row in rows {
                    let idExpr = SQLExpression<String>("id")
                    let rowIDStr = row[idExpr]

                    if let inverseInformation,
                       let mismatch = row.checkFieldMatchesRelationship(
                           id: idStr,
                           key: relationship.key,
                           information: inverseInformation,
                           ulids,
                           rowIDStr: rowIDStr,
                       )
                    { inverseMismatches[relationship.key, default: [:]][rowIDStr] = mismatch }

                    let index = stringArray.firstIndex(of: rowIDStr)!
                    stringArray.remove(at: index)
                }

                if !removingStaleReferences {
                    for string in stringArray {
                        inverseMismatches[
                            relationship.key,
                            default: [:]
                        ][string] = .missingInInverse
                    }
                } else {
                    var strings = ulids.map(\.ulidString)
                    strings.removeAll {
                        stringArray.contains($0)
                    }
                    let string = strings.map { "\"\($0)\""}.joined(separator: ",")
                    setters.append(
                        SQLiteJSONB(jsonString: "[" + string + "]")
                            .sqliteSetter(key: relationship.key)
                    )
                }
            } else if
                relationship.relationshipType == .one,
                let _ = ULID(fromPersistent: string)
            {
                let query = Table(relationship.relationshipToType!.schema)
                    .select(fieldsToFetch)
                    .where(idExpr == string)
                    .limit(1)

                var rows: AnySequence<Row>
                do {
                    rows = try connection.prepare(query)
                } catch let error as SQLiteDB.Result {
                    let parsed = error.parse()
                    if case .noSuchTable = parsed {
                        if !removingStaleReferences {
                            inverseMismatches[
                                relationship.key,
                                default: [:]
                            ][string] = .missingInInverse
                        } else {
                            let str: String? = nil
                            setters.append(str.sqliteSetter(key: relationship.key))
                        }
                        continue
                    }
                    throw error
                }

                var called = false
                for row in rows {
                    if let inverseInformation,
                       let mismatch = row.checkFieldMatchesRelationship(
                           id: idStr,
                           key: relationship.key,
                           information: inverseInformation,
                       )
                    {
                        inverseMismatches[relationship.key, default: [:]][string] = mismatch
                    }
                    called = true
                }

                if !called {
                    if !removingStaleReferences {
                        inverseMismatches[
                            relationship.key,
                            default: [:]
                        ][string] = .missingInInverse
                    } else {
                        let str: String? = nil
                        setters.append(str.sqliteSetter(key: relationship.key))
                    }
                }
            } else {
                localMismatches[relationship.key] = .corruptedData
                continue
            }
        }

        if !setters.isEmpty {
            let update = Table(type.schema)
                .filter(SQLExpression<String>("id") == idStr)
                .update(setters)
            try connection.run(update)
        }

        return (localMismatches, inverseMismatches)
    }
}

extension SQLiteDB.Row {
    fileprivate nonisolated func checkFieldMatchesRelationship(
        id: String,
        key: String,
        information: FieldInformation,
        _ ulids: [ULID],
        rowIDStr: String
    ) -> RelationshipIntegrityReport.Mismatch? {
        let value = SQLiteValue(
            typeName: information.typeName,
            key: information.key,
            row: self
        )

        if case .null = value {
            return .inverseMismatch(found: nil, expected: id)
        }

        guard case .text(let string) = value else {
            return .inverseUnexpectedlyNotRelationship
        }

        if
            information.relationshipType == .many,
            let foundUlids = [ULID](fromPersistent: SQLiteJSONB(jsonString: string))
        {
            let countOfRowInOriginal = ulids.count { $0.ulidString == rowIDStr }
            let countOfRowInFound = foundUlids.count { $0.ulidString == id }

            if countOfRowInOriginal != countOfRowInFound {
                return .inverseCountMismatch(
                    found: countOfRowInFound,
                    expected: countOfRowInOriginal
                )
            }
        } else if
            information.relationshipType == .one,
            let _ = ULID(fromPersistent: string)
        {
            if string != id {
                return .inverseMismatch(found: string, expected: id)
            }
        } else {
            return .corruptedData
        }
        return nil
    }

    fileprivate nonisolated func checkFieldMatchesRelationship(
        id: String,
        key: String,
        information: FieldInformation
    ) -> RelationshipIntegrityReport.Mismatch? {
        let value = SQLiteValue(
            typeName: information.typeName,
            key: information.key,
            row: self
        )

        if case .null = value {
            return .inverseMismatch(found: nil, expected: id)
        }

        guard case .text(let string) = value else {
            return .inverseUnexpectedlyNotRelationship
        }

        if information.relationshipType == .many,
           let foundUlids = [ULID](fromPersistent: SQLiteJSONB(jsonString: string))
        {
            let countOfRowInFound = foundUlids.count { $0.ulidString == id }

            if countOfRowInFound < 1 {
                return .inverseCountMismatch(found: 0, expected: 1)
            }
        } else if
            information.relationshipType == .one,
            let _ = ULID(fromPersistent: string)
        {
            if string != id {
                return .inverseMismatch(found: string, expected: id)
            }
        } else {
            return .corruptedData
        }

        return nil
    }
}
