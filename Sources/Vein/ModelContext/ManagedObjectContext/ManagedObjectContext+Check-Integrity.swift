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
        of model: Model.Type
    ) throws (MOCError) -> RelationshipIntegrityReport {
        guard modelContainer.versionedSchema.models.contains(where: {
            ObjectIdentifier($0) == ObjectIdentifier(model)
        }) else {
            throw MOCError.inactiveModelTypeFetched(model)
        }

        let relationships = model._fieldInformation.filter {
            $0.relationshipToType != nil
        }

        if relationships.isEmpty {
            return RelationshipIntegrityReport(schema: model.schema, models: [])
        }

        var models = [RelationshipIntegrityReport.Model]()
        let idExpr = SQLExpression<String>("id")

        var fieldsToLoad = relationships.map(\.fetchExpressible)
        fieldsToLoad.append(idExpr)
        let request = Table(model.schema).select(fieldsToLoad)

        do {
            let result = try connection.prepare(request)

            for row in result {
                let idStr = row[idExpr]
                guard let id = ULID(ulidString: idStr) else {
                    models.append(
                        RelationshipIntegrityReport.Model(
                            idString: idStr,
                            localMismatches: [
                                "id": .corruptedData
                            ],
                            inverseMismatches: [:]
                        )
                    )
                    continue
                }

                let (localMismatches, inverseMismatches) = try relationships.checkIntegrity(
                    type: model,
                    connection: connection,
                    row: row,
                    id: id
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

    /// Checks the plausibility for all relationships of a row for each row for all schemas this context manages
    ///
    /// Saves will be locked while running the integrity check.
    public nonisolated func checkRelationshipIntegrity() throws(MOCError)
        -> [RelationshipIntegrityReport]
    {
        saveLock.lock()
        defer {
            saveLock.unlock()
        }
        var reports = [RelationshipIntegrityReport]()
        for model in modelContainer.versionedSchema.models {
            try reports.append(_checkRelationshipIntegrity(of: model))
        }
        return reports
    }

    /// Checks the plausibility for all relationships of a row for each row for all specified schemas.
    ///
    /// Saves will be locked while running the integrity check.
    public nonisolated func checkRelationshipIntegrity(
        for models: [any PersistentModel.Type]
    ) throws(MOCError) -> [RelationshipIntegrityReport] {
        saveLock.lock()
        defer {
            saveLock.unlock()
        }
        var reports = [RelationshipIntegrityReport]()
        for model in models {
            try reports.append(_checkRelationshipIntegrity(of: model))
        }
        return reports
    }

    /// Checks the plausibility for all relationships of a row for each row currently in the specified table.
    ///
    /// Saves will be locked while running the integrity check.
    public nonisolated func checkRelationshipIntegrity<Model: PersistentModel>(
        of model: Model.Type
    ) throws(MOCError) -> RelationshipIntegrityReport {
        saveLock.lock()
        defer {
            saveLock.unlock()
        }
        return try _checkRelationshipIntegrity(of: model)
    }
}

extension [FieldInformation] {
    fileprivate func checkIntegrity<Model: PersistentModel>(
        type: Model.Type,
        connection: SQLiteDB.Connection,
        row: SQLiteDB.Row,
        id: ULID
    ) throws -> (
        localMismatches: [String: RelationshipIntegrityReport.Mismatch],
        inverseMismatches: [String: [String: RelationshipIntegrityReport.Mismatch]]
    ) {
        var localMismatches = [String: RelationshipIntegrityReport.Mismatch]()
        var inverseMismatches = [String: [String: RelationshipIntegrityReport.Mismatch]]()

        var inverses = [String: String]()
        var inverseInformation = [String: FieldInformation]()
        let idExpr = SQLExpression<String>("id")

        for inverse in type._inverseFields.values {
            for (key, value) in inverse {
                // Safe under the assumption that the information is macro generated
                // and the generated information is correct.
                inverses[value] = key
            }
        }

        for information in self {
            guard let oppositeType = information.relationshipToType else { continue }
            if
                let inversesToThis = oppositeType._inverseFields[type.typeIdentifier],
                let key = inversesToThis[information.key]
            { inverses[information.key] = key }

            if let inverse = inverses[information.key] {
                inverseInformation[information.key] = oppositeType._fieldInformation.first {
                    $0.key == inverse
                }
            }
        }

        for relationship in self
            where inverses[relationship.key] != nil
            && inverseInformation[relationship.key] != nil
        {
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

            let inverseInformation = inverseInformation[relationship.key]!

            if relationship.relationshipType == .many,
               let ulids = [ULID](fromPersistent: SQLiteJSONB(jsonString: string))
            {
                let uniqued = Set(ulids)
                var stringArray = uniqued.map(\.ulidString)
                let query = Table(relationship.relationshipToType!.schema)
                    .select([idExpr, inverseInformation.fetchExpressible])
                    .where(stringArray.contains(idExpr))

                var rows: AnySequence<Row>
                do {
                    rows = try connection.prepare(query)
                } catch let error as SQLiteDB.Result {
                    let parsed = error.parse()
                    if case .noSuchTable = parsed {
                        for ulid in ulids {
                            inverseMismatches[
                                relationship.key,
                                default: [:]
                            ][ulid.ulidString] = .missingInInverse
                        }
                        return (localMismatches, inverseMismatches)
                    }
                    throw error
                }

                for row in rows {
                    let idExpr = SQLExpression<String>("id")
                    let rowIDStr = row[idExpr]

                    if let mismatch = row.checkFieldMatchesRelationship(
                        id: id,
                        key: relationship.key,
                        information: inverseInformation,
                        ulids,
                        rowIDStr: rowIDStr,
                    ) {
                        inverseMismatches[relationship.key, default: [:]][rowIDStr] = mismatch
                    }

                    let index = stringArray.firstIndex(of: rowIDStr)!
                    stringArray.remove(at: index)
                }

                for string in stringArray {
                    inverseMismatches[relationship.key, default: [:]][string] = .missingInInverse
                }
            } else if
                relationship.relationshipType == .one,
                let _ = ULID(fromPersistent: string)
            {
                let query = Table(relationship.relationshipToType!.schema)
                    .select([idExpr, inverseInformation.fetchExpressible])
                    .where(idExpr == string)
                    .limit(1)

                var rows: AnySequence<Row>
                do {
                    rows = try connection.prepare(query)
                } catch let error as SQLiteDB.Result {
                    let parsed = error.parse()
                    if case .noSuchTable = parsed {
                        inverseMismatches[
                            relationship.key,
                            default: [:]
                        ][string] = .missingInInverse
                        return (localMismatches, inverseMismatches)
                    }
                    throw error
                }

                var called = false
                for row in rows {
                    if let mismatch = row.checkFieldMatchesRelationship(
                        id: id,
                        key: relationship.key,
                        information: inverseInformation,
                    ) {
                        inverseMismatches[relationship.key, default: [:]][string] = mismatch
                    }
                    called = true
                }

                if !called {
                    inverseMismatches[relationship.key, default: [:]][string] = .missingInInverse
                }
            } else {
                localMismatches[relationship.key] = .corruptedData
                continue
            }
        }

        return (localMismatches, inverseMismatches)
    }
}

extension SQLiteDB.Row {
    fileprivate nonisolated func checkFieldMatchesRelationship(
        id: ULID,
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

        if information.relationshipType == .many,
           let foundUlids = [ULID](fromPersistent: SQLiteJSONB(jsonString: string))
        {
            let countOfRowInOriginal = ulids.count { $0.ulidString == rowIDStr }
            let countOfRowInFound = foundUlids.count { $0.ulidString == id.ulidString }

            if countOfRowInOriginal != countOfRowInFound {
                return .inverseCountMismatch(
                    found: countOfRowInFound,
                    expected: countOfRowInOriginal
                )
            }
        } else if information.relationshipType == .one,
                  let ulid = ULID(fromPersistent: string)
        {
            if ulid != id {
                return .inverseMismatch(found: ulid, expected: id)
            }
        } else {
            return .corruptedData
        }
        return nil
    }

    fileprivate nonisolated func checkFieldMatchesRelationship(
        id: ULID,
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
            let countOfRowInFound = foundUlids.count { $0.ulidString == id.ulidString }

            if countOfRowInFound < 1 {
                return .inverseCountMismatch(found: 0, expected: 1)
            }
        } else if information.relationshipType == .one,
                  let ulid = ULID(fromPersistent: string)
        {
            if ulid != id {
                return .inverseMismatch(found: ulid, expected: id)
            }
        } else {
            return .corruptedData
        }

        return nil
    }
}
