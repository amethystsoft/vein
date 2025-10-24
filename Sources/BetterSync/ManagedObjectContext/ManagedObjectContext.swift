import SQLite

@MainActor
public class ManagedObjectContext {
    public static var shared: ManagedObjectContext?
    public static var instance: ManagedObjectContext {
        guard let shared else {
            fatalError("ManagedObjectContext.shared not set")
        }
        return shared
    }
    private var connection: Connection
    
    /// Connects to database at `path`, creates a new one if it doesn't exist
    init(path: String) throws(ManagedObjectContextError) {
        do {
            self.connection = try Connection(path)
        } catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(error.localizedDescription)
        }
    }
    
    /// In memory only
    init() throws(ManagedObjectContextError) {
        do {
            self.connection = try Connection(.inMemory)
        } catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(error.localizedDescription)
        }
    }
}
