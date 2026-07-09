import Foundation
import Testing
import VeinCore
import VeinTesting

@MainActor
struct FullChain {
    @Test
    func fullChainVerification() async throws {
        let tester = try MigrationTester(migrationPlan: MigrationPlan.self)
        
        let username = "miakoring"
        let bio = "Amethyst Vein"
        let email = "example@amethystsoft.de"
        
        try tester.testCompleteChain(
            initialData: { context in
                let user = Version1.User(username: username)
                let profile = Version1.Profile(bio: bio)
                
                try context.insert(user)
                try context.insert(profile)
                try context.save()
            },
            validations: [
                
            ]
        )
    }
}
