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
        
        var fieldsToLoad = relationships.map { $0.fetchExpressible }
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
            throw error.parse()
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
    public nonisolated func checkRelationshipIntegrity() throws(MOCError) -> [RelationshipIntegrityReport] {
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
    public nonisolated func checkRelationshipIntegrity(for models: [any PersistentModel.Type]) throws(MOCError) -> [RelationshipIntegrityReport] {
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
        
        for information in self where !inverses.keys.contains(information.key) {
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
        
        for relationship in self where inverses[relationship.key] != nil && inverseInformation[relationship.key] != nil {
            let value = SQLiteValue(
                typeName: relationship.typeName,
                key: relationship.key,
                row: row
            )
            
            if case .null = value {
                continue
            }
            
            guard case .text(let string) = value else {
                print(value)
                localMismatches[relationship.key] = .unexpectedlyNotRelationship
                continue
            }
            
            let inverseInformation = inverseInformation[relationship.key]!
            
            if
                string.hasPrefix("["),
                let ulids = [ULID](fromPersistent: SQLiteJSONB(jsonString: string)) {
                let uniqued = Set(ulids)
                var stringArray = uniqued.map(\.ulidString)
                let query = Table(relationship.relationshipToType!.schema)
                    .select([idExpr, inverseInformation.fetchExpressible])
                    .where(stringArray.contains(idExpr))
                
                let rows = try connection.prepare(query)
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
                        inverseMismatches[relationship.key, default: [:]][string] = mismatch
                    }
                    
                    let index = stringArray.firstIndex(of: rowIDStr)!
                    stringArray.remove(at: index)
                }
                
                for string in stringArray {
                    inverseMismatches[relationship.key, default: [:]][string] = .modelNotFound
                }
            } else if let _ = ULID(fromPersistent: string) {
                let query = Table(relationship.relationshipToType!.schema)
                    .select([idExpr, inverseInformation.fetchExpressible])
                    .where(idExpr == string)
                    .limit(1)
                
                let rows = try connection.prepare(query)
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
                    inverseMismatches[relationship.key, default: [:]][string] = .modelNotFound
                }
            } else {
                localMismatches[relationship.key] = .unexpectedlyNotRelationship
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
        
        if string.hasPrefix("["),
            let foundUlids = [ULID](fromPersistent: SQLiteJSONB(jsonString: string)) {
            let countOfRowInOriginal = ulids.count { $0.ulidString == rowIDStr }
            let countOfRowInFound = foundUlids.count { $0.ulidString == id.ulidString }
            
            if countOfRowInOriginal != countOfRowInFound {
                return .inverseCountMismatch(found: countOfRowInFound, expected: countOfRowInOriginal)
            }
        } else if let ulid = ULID(fromPersistent: string) {
            if ulid != id {
                return .inverseMismatch(found: ulid, expected: id)
            }
        } else {
            return .inverseUnexpectedlyNotRelationship
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
        
        if string.hasPrefix("["),
            let foundUlids = [ULID](fromPersistent: SQLiteJSONB(jsonString: string))
        {
            let countOfRowInFound = foundUlids.count { $0.ulidString == id.ulidString }
            
            if countOfRowInFound < 1 {
                return .missingInInverse
            }
        } else if let ulid = ULID(fromPersistent: string) {
            if ulid != id {
                return .inverseMismatch(found: ulid, expected: id)
            }
        } else {
            return .inverseUnexpectedlyNotRelationship
        }
        
        return nil
    }
}
