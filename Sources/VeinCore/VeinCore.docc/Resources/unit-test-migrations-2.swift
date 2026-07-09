import Foundation
import Testing
import VeinCore
import VeinTesting

@MainActor
struct StepByStep {
    @Test
    func stepByStepVerification() async throws {
        let tester = try MigrationTester(migrationPlan: MigrationPlan.self)
        
        let username = "miakoring"
        let bio = "Amethyst Vein"
        let email = "example@amethystsoft.de"
        
        try tester.seed(
            version: Version1.self,
            with: { context in
                let user = Version1.User(username: username)
                let profile = Version1.Profile(bio: bio)
                
                try context.insert(user)
                try context.insert(profile)
                try context.save()
            }
        )
        
        try tester.migrateAndCheck(
            version: Version2.self,
            with: { context in
                let users = try context
                    .fetchAll(Version2.User.self)
                #expect(users.count == 1)
                
                if let user = users.first {
                    #expect(user.username == username)
                    #expect(user.email == nil)
                    
                    user.email = email
                }
                
                let profiles = try context
                    .fetchAll(Version2.Profile.self)
                #expect(profiles.count == 1)
                
                if let profile = profiles.first {
                    #expect(profile.bio == bio)
                }
                
                try context.save()
            }
        )
    }
}
