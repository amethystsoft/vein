import ULID

extension ManagedObjectContext {
    public nonisolated func getModel<T: PersistentModel>(id: ULID, type: T.Type) throws(MOCError) -> T? {
        if let model = identityMap.getTracked(type, id: id) {
            return model
        }
        
        return try self.fetchAll(PredicateBuilder<T>().addCheck(.isEqualTo, "id", id)).first
    }
}
