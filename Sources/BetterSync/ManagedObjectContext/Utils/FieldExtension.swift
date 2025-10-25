extension [PersistedField] {
    @MainActor
    public var eagerLoaded: [PersistedField] {
        self.compactMap {
            if $0.isLazy { return nil }
            return $0
        }
    }
}
