import SQLiteDB

struct Vein1_1_1RelationshipReferenceBalanceHeal: AutohealImplementation {
    func run(with container: ModelContainer) throws {
        let modelsWithRelationship = container.versionedSchema.models
            .filter { model in
                model._fieldInformation.contains { information in
                    information.relationshipToType != nil
                }
            }
        
        for schema in modelsWithRelationship {
            var page: Int = 0
            
            var breakLoop = false
            repeat {
                try repairModel(
                    with: container.getConnection(),
                    model: schema,
                    page: page,
                    breakLoop: &breakLoop)
            } while !breakLoop
        }
    }
    
    func repairModel<T: PersistentModel>(
        with connection: Connection,
        model: T.Type,
        page: Int,
        breakLoop: inout Bool
    ) throws {
        let information = T._fieldInformation.filter {
            $0.relationshipToType != nil
        }
        
        let table = Table(T.schema)
        var fieldsToLoad = information.map(\.fetchExpressible)
        fieldsToLoad.append(SQLExpression<String>("id"))
        let select = table.select(fieldsToLoad)
        
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
        
        guard let results else {
            return
        }
        
        for row in results {
            for info in information {
                
            }
        }
    }
}
