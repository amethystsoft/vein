import Foundation
import Testing
import VeinCore
import VeinTesting

@MainActor
struct FullChain {
    @Test
    func fullChainVerification() async throws {
        let tester = try MigrationTester(migrationPlan: MigrationPlan.self)
    }
}
