import Foundation
protocol DiskUsingTest {
    var additionalPath: String { get }
}

extension DiskUsingTest {
    func prepareContainerLocation(name: String) throws -> String? {
        let containerPath = FileManager.default.temporaryDirectory
        
        let dbDir = containerPath.relativePath.appending("/veinTests/\(testID.uuidString)\(additionalPath)")
        
        let shouldRunInMemory = ProcessInfo.processInfo.environment["TestOnDisk"] == nil
        
        if shouldRunInMemory {
            return nil
        }
        
        let dbPath = dbDir.appending("/\(name).sqlite3")
        
        try FileManager.default.createDirectory(
            atPath: dbDir,
            withIntermediateDirectories: true
        )
        
        return dbPath
    }
}
