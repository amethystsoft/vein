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
        
        try tester.migrateAndCheck(
            version: Version3.self,
            with: { context in
                let users = try context
                    .fetchAll(Version3.User.self)
                #expect(users.count == 1)
                
                let profiles = try context
                    .fetchAll(Version3.Profile.self)
                #expect(profiles.count == 1)
                
                if let profile = profiles.first {
                    #expect(profile.bio == bio)
                    #expect(profile.internalID.hasPrefix("ID-"))
                    if let id = Int(profile.internalID.dropFirst(3)) {
                        #expect((1000...9999).contains(id))
                    } else {
                        Issue.record("Internal ID should be a number after `ID-` prefix")
                    }
                }
            }
        )
    }
}
