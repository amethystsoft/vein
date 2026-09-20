import Foundation
import Testing
import Logging
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct AutohealTests {
    func createSeededDB(from: String) throws -> Connection {
        let connection = try Connection()
        var pathToDump = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        pathToDump = pathToDump
            .appendingPathComponent("dumps")
            .appendingPathComponent("vein1_1_1RelationshipReferenceHealSeed-dump.sql")
        
        let data = try Data(contentsOf: pathToDump)
        try connection.execute(String(data: data, encoding: .utf8)!)
        
        return connection
    }
    
    
}
