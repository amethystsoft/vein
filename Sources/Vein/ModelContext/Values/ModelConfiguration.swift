public struct ModelConfiguration: Sendable {
    /// Whether to clean up stale identity map entries on ``ManagedObjectContext/save()``.
    public var cleanStaleIdentityMapEntriesOnSave: Bool = true
    
    /// Whether to schedule cleans on the context actor and with which timeout.
    ///
    /// Disabled via `nil` by default.
    public var cleanStaleIdentityMapEntriesTimeoutSeconds: UInt16? = nil
    
    /// Creates a default ``ModelConfiguration``
    public init() {}
    
    public static var `default`: Self { .init() }
}
