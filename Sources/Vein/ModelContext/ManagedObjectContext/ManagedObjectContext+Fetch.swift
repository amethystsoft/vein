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

import SQLiteDB
import ULID
import Foundation

extension ManagedObjectContext {
    /// Returns all models matching the predicate.
    nonisolated func _fetchAll<T: PersistentModel>(_ predicate: ModelPredicate<T>) throws(MOCError)
        -> [T]
    {
        do {
            let table = Table(T.schema).filter(predicate.sql)
            let eagerLoadedFields = T._fieldInformation.eagerLoaded

            var fieldsToLoad = eagerLoadedFields.map(\.fetchExpressible)
            fieldsToLoad.append(SQLExpression<String>("id"))
            let select = table.select(fieldsToLoad)

            if modelContainer.logConfiguration.sqlQueries {
                Self.logger.info(
                    "Fetching \(T.self) with \nQuery: '\(select.expression.template)'\nBindings:\(select.expression.bindings)"
                )
            }

            var models = [T]()

            var currentlyDeleted = [ULID: any PersistentModel]()
            var currentlyInserted = [ULID: any PersistentModel]()
            var currentlyTouched = [ULID: any PersistentModel]()

            writeCache.mutate { inserted, touched, deleted,_ in
                currentlyInserted = inserted[T.typeIdentifier] ?? [:]
                currentlyTouched = touched[T.typeIdentifier] ?? [:]
                currentlyDeleted = deleted[T.typeIdentifier] ?? [:]
            }

            var results: AnySequence<Row>? = nil
            do {
                results = try connection.prepare(select)
            } catch let error as SQLiteDB.Result {
                switch error.parse() {
                    case .noSuchTable:
                        break
                    default: throw error
                }
            }
            var resultIDs = Set<ULID>()

            if let results {
                identityMap.batched { getTracked, startTracking in
                    for row in results {
                        let id = ULID(ulidString: row[SQLExpression<String>("id")])!

                        if currentlyDeleted[id] != nil { continue }

                        if let alreadyTrackedModel = getTracked(T.self, id) {
                            if predicate.runtimeFilter(alreadyTrackedModel) {
                                models.append(alreadyTrackedModel)
                                resultIDs.insert(alreadyTrackedModel.id)
                            }
                            continue
                        }
                        var fields = [String: SQLiteValue]()

                        for field in eagerLoadedFields {
                            fields[field.key] = SQLiteValue(
                                typeName: field.typeName,
                                key: field.key,
                                row: row
                            )
                        }

                        let model = T(id: id, fields: fields)
                        model.context = self
                        models.append(model)
                        resultIDs.insert(model.id)
                        startTracking(model)
                    }
                }
            }

            for (_, insert) in currentlyInserted {
                if
                    !resultIDs.contains(insert.id),
                    let model = insert as? T,
                    predicate.runtimeFilter(model)
                {
                    models.append(model)
                }
            }

            for (_, touch) in currentlyTouched {
                if
                    !resultIDs.contains(touch.id),
                    let model = touch as? T,
                    predicate.runtimeFilter(model)
                { models.append(model) }
            }

            return models
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }

    nonisolated func _fetchSingleProperty<Field: PersistedField>(field: Field) throws(MOCError)
        -> Field.WrappedType.PersistentRepresentation
    {
        typealias T = Field.WrappedType
        guard let key = field.key else {
            if let model = field.model {
                throw MOCError
                    .keyMissing(
                        message: "raised by schema \(model._getSchema()) on property of type '\(T.self)'"
                    )
            } else {
                throw MOCError
                    .keyMissing(message: "raised by unknown schema on property of type '\(T.self)'")
            }
        }
        guard let model = field.model
        else {
            throw MOCError.modelReference(message: "raised by field with property name '\(key)'")}

        let table = Table(model._getSchema())
            .filter(SQLExpression<String>("id") == model.id.ulidString)
        let select = table.select(distinct: [field.fetchExpressible]).limit(1)

        if modelContainer.logConfiguration.sqlQueries {
            Self.logger.info(
                "Fetching \(field.instanceKey) of \(model._getSchema()) with \nQuery: '\(select.expression.template)'\nBindings:\(select.expression.bindings)"
            )
        }

        do {
            for row in try connection.prepare(select) {
                return field.decode(row)
            }
            throw MOCError
                .unexpectedlyEmptyResult(
                    message: "raised by field with property name '\(key)' of Model '\(T.self)' with id \(model.id.ulidString)"
                )
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }

    nonisolated func getAllStoredSchemas() throws -> [String] {
        let tables = try connection.schema.objectDefinitions(type: .table)
        return tables.map(\.name).filter {
            [
                MigrationTable.schema
            ].contains($0) == false &&
                !$0.starts(with: "sqlite_")
        }
    }

    nonisolated func getNonEmptySchemas() throws -> [String] {
        let tables = try connection.schema.objectDefinitions(type: .table)
        let filtered = tables.map(\.name).filter {
            [
                MigrationTable.schema
            ].contains($0) == false &&
                !$0.starts(with: "sqlite_")
        }

        var nonEmpty = [String]()
        for table in filtered {
            guard try connection.scalar(Table(table).count) > 0 else { continue }
            nonEmpty.append(table)
        }

        return nonEmpty
    }
}
