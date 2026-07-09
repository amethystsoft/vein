import Foundation
import Testing
import VeinCore
import VeinTesting

@MainActor
struct StepByStep {
    @Test
    func stepByStepVerification() async throws {
        let tester = try MigrationTester(migrationPlan: MigrationPlan.self)
    }
}
