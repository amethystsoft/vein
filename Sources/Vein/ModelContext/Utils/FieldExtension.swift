extension [PersistedField] {
    var eagerLoaded: [any PersistedField] {
        self.compactMap {
            if $0.isLazy { return nil }
            return $0
        }
    }
}
