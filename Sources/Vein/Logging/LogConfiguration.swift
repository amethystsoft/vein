/// A configuration for ``ModelContainer`` to configure the amount of information you want to be logged.
public struct LogConfiguration: Sendable {
    /// Whether to log every sql query.
    public var sqlQueries: Bool
    /// Whether to log when a potential data corruption is found.
    public var potentialDataCorruption: Bool
    /// Whether to log when a potential data corruption is found during a migration.
    public var potentialDataCorruptionInMigration: Bool
    /// Whether to log when a result is empty but results were expected.
    public var unexpectedlyEmptyResults: Bool
    /// Whether to log when a an error occurs during a cascading deletion.
    public var errorWhileCascadeDeletion: Bool
    /// Whether to log when it was attempted to mutate a primary key on a managed model.
    public var primaryKeyMutation: Bool
    /// Whether to log ``ManagedObjectContext`` errors.
    public var modelContextErrors: Bool

    /// Create a new ``LogConfiguration``.
    public init(
        sqlQueries: Bool,
        potentialDataCorruption: Bool,
        potentialDataCorruptionInMigration: Bool,
        unexpectedlyEmptyResults: Bool,
        errorWhileCascadeDeletion: Bool,
        primaryKeyMutation: Bool,
        modelContextErrors: Bool
    ) {
        self.sqlQueries = sqlQueries
        self.potentialDataCorruption = potentialDataCorruption
        self.potentialDataCorruptionInMigration = potentialDataCorruptionInMigration
        self.unexpectedlyEmptyResults = unexpectedlyEmptyResults
        self.errorWhileCascadeDeletion = errorWhileCascadeDeletion
        self.primaryKeyMutation = primaryKeyMutation
        self.modelContextErrors = modelContextErrors
    }

    /// A LogConfiguration recommended for debug builds.
    public static var debug: Self {
        LogConfiguration(
            sqlQueries: false,
            potentialDataCorruption: true,
            potentialDataCorruptionInMigration: true,
            unexpectedlyEmptyResults: true,
            errorWhileCascadeDeletion: true,
            primaryKeyMutation: true,
            modelContextErrors: true
        )
    }

    /// A LogConfiguration recommended for release builds.
    public static var release: Self {
        LogConfiguration(
            sqlQueries: false,
            potentialDataCorruption: true,
            potentialDataCorruptionInMigration: true,
            unexpectedlyEmptyResults: false,
            errorWhileCascadeDeletion: false,
            primaryKeyMutation: false,
            modelContextErrors: true
        )
    }
}
