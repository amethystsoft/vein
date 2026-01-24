import Testing
@testable import VeinTesting
import Vein
import VeinCore

@MainActor
struct StepByStep {
    @Test
    func stepByStepVerification() async throws {
        let tester = try MigrationTester(migrationPlan: MigrationPlan.self)
        
        let username = "miakoring"
        let bio = "Amethyst Vein"
        
        let postContent = "Amethyst Vein Release Notes"
        
        let email = "example@amethystsoft.de"
        
        let postCategory = "blog"
        
        var recordedInternalID: String?
        
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
                    .fetchAll(Version2.User._PredicateHelper()._builder())
                #expect(users.count == 1)
                
                if let user = users.first {
                    #expect(user.username == username)
                    #expect(user.email == nil)
                    
                    user.email = email
                }
                
                let profiles = try context
                    .fetchAll(Version2.Profile._PredicateHelper()._builder())
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
                    .fetchAll(Version3.User._PredicateHelper()._builder())
                #expect(users.count == 1)
                
                let profiles = try context
                    .fetchAll(Version3.Profile._PredicateHelper()._builder())
                #expect(profiles.count == 1)
                
                if let profile = profiles.first {
                    #expect(profile.bio == bio)
                    #expect(profile.internalID.hasPrefix("ID-"))
                    if let id = Int(profile.internalID.dropFirst(3)) {
                        #expect((1000...9999).contains(id))
                    } else {
                        Issue.record("Internal ID should be a number after `ID-` prefix")
                    }
                    
                    recordedInternalID = profile.internalID
                }
                
                // create Post to exist going forward
                let post = Version3.Post(content: postContent)
                try context.insert(post)
                try context.save()
            }
        )
        
        try tester.migrateAndCheck(
            version: Version4.self,
            with: { context in
                let users = try context
                    .fetchAll(Version4.User._PredicateHelper()._builder())
                #expect(users.count == 1)
                
                let profiles = try context
                    .fetchAll(Version4.Profile._PredicateHelper()._builder())
                #expect(profiles.count == 1)
                
                let posts = try context.fetchAll(Version4.Post._PredicateHelper()._builder())
                #expect(posts.count == 1)
                
                if let post = posts.first {
                    #expect(post.content == postContent)
                    #expect(post.category == nil)
                    post.category = postCategory
                }
                try context.save()
            }
        )
        
        try tester.migrateAndCheck(
            version: Version5.self,
            with: { context in
                let users = try context
                    .fetchAll(Version5.User._PredicateHelper()._builder())
                #expect(users.count == 1)
                
                if let user = users.first {
                    #expect(user.displayName == username.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                    #expect(user.email == nil)
                }
                
                let profiles = try context
                    .fetchAll(Version5.Profile._PredicateHelper()._builder())
                #expect(profiles.count == 1)
                
                if let profile = profiles.first {
                    #expect(profile.bio == bio)
                    #expect(profile.internalID == recordedInternalID)
                    #expect(recordedInternalID != nil)
                }
                
                let posts = try context.fetchAll(Version5.Post._PredicateHelper()._builder())
                #expect(posts.count == 1)
                
                if let post = posts.first {
                    #expect(post.content == postContent)
                    #expect(post.category == nil)
                }
            }
        )
    }
}

fileprivate enum Version1: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self, Profile.self
    ]}
    
    @Model
    final class User {
        @Field var username: String
        init(username: String) { self.username = username }
    }
    
    @Model
    final class Profile {
        @Field var bio: String
        init(bio: String) { self.bio = bio }
    }
}

fileprivate enum Version2: VersionedSchema {
    static let version = ModelVersion(1, 1, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self, Profile.self
    ]}
    
    @Model
    final class User {
        @Field var username: String
        // Added field
        @Field var email: String?
        init(username: String, email: String?) {
            self.username = username
            self.email = email
        }
    }
    
    @Model
    final class Profile {
        @Field var bio: String
        init(bio: String) { self.bio = bio }
    }
}

fileprivate enum Version3: VersionedSchema {
    static let version = ModelVersion(1, 2, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self, Profile.self, Post.self
    ]}
    
    @Model
    final class User {
        @Field var username: String
        @Field var email: String?
        init(username: String, email: String?) {
            self.username = username
            self.email = email
        }
    }
    
    @Model
    final class Profile {
        @Field var bio: String
        // added field
        @Field var internalID: String
        init(bio: String, internalID: String) {
            self.bio = bio
            self.internalID = internalID
        }
    }
    
    @Model
    final class Post {
        @Field var content: String
        init(content: String) { self.content = content }
    }
}

fileprivate enum Version4: VersionedSchema {
    static let version = ModelVersion(1, 3, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self, Profile.self, Post.self
    ]}
    
    @Model
    final class User {
        @Field var username: String
        @Field var email: String?
        init(username: String, email: String?) {
            self.username = username
            self.email = email
        }
    }
    
    @Model
    final class Profile {
        @Field var bio: String
        @Field var internalID: String
        init(bio: String, internalID: String) {
            self.bio = bio
            self.internalID = internalID
        }
    }
    
    @Model
    final class Post {
        @Field var content: String
        
        // Added field
        @Field var category: String?
        
        init(content: String, category: String) {
            self.content = content
            self.category = category
        }
    }
}

fileprivate enum Version5: VersionedSchema {
    static let version = ModelVersion(2, 0, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self, Profile.self, Post.self
    ]}
    
    @Model
    final class User {
        // Renamed/Transformed from username
        @Field var displayName: String
        @Field var email: String?
        init(displayName: String, email: String?) {
            self.displayName = displayName
            self.email = email
        }
    }
    
    @Model
    final class Profile {
        @Field var bio: String
        @Field var internalID: String
        init(bio: String, internalID: String) {
            self.bio = bio
            self.internalID = internalID
        }
    }
    
    @Model
    final class Post {
        @Field var content: String
        @Field var category: String?
        init(content: String, category: String) {
            self.content = content
            self.category = category
        }
    }
}

fileprivate enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self,
        Version2.self,
        Version3.self,
        Version4.self,
        Version5.self
    ]}
    
    static var stages: [Vein.MigrationStage] {[
        v1ToV2, v2ToV3, v3ToV4, v4ToV5
    ]}
    
    // V1 -> V2: Simple additions and unchanged
    static let v1ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version1.self,
        toVersion: Version2.self,
        willMigrate: { context in
            try Version1.User.fieldsAddedMigration(to: Version2.User.self, on: context)
            try Version1.Profile.unchangedMigration(to: Version2.Profile.self, on: context)
        },
        didMigrate: nil
    )
    
    // V2 -> V3: Logic-based transformation (Fetch and Reinsert)
    static let v2ToV3 = Vein.MigrationStage.complex(
        fromVersion: Version2.self,
        toVersion: Version3.self,
        willMigrate: { context in
            // Basic migrations
            try Version2.User.unchangedMigration(to: Version3.User.self, on: context)
            
            // Logic migration for Profile
            let oldProfiles = try context.fetchAll(Version2.Profile._PredicateHelper()._builder())
            for old in oldProfiles {
                let new = Version3.Profile(
                    bio: old.bio,
                    internalID: "ID-\(Int.random(in: 1000...9999))"
                )
                try context.insert(new)
                try context.delete(old)
            }
        },
        didMigrate: nil
    )
    
    // V3 -> V4: Field addition and unchanged
    static let v3ToV4 = Vein.MigrationStage.complex(
        fromVersion: Version3.self,
        toVersion: Version4.self,
        willMigrate: { context in
            try Version3.User.unchangedMigration(to: Version4.User.self, on: context)
            try Version3.Profile.unchangedMigration(to: Version4.Profile.self, on: context)
            try Version3.Post.fieldsAddedMigration(to: Version4.Post.self, on: context)
        },
        didMigrate: nil
    )
    
    // V4 -> V5: Data cleaning/transformation (Fetch and Reinsert)
    static let v4ToV5 = Vein.MigrationStage.complex(
        fromVersion: Version4.self,
        toVersion: Version5.self,
        willMigrate: { context in
            try Version4.Profile.unchangedMigration(to: Version5.Profile.self, on: context)
            try Version4.Post.unchangedMigration(to: Version5.Post.self, on: context)
            
            // Transform User.username to User.displayName with sanitization
            let oldUsers = try context.fetchAll(Version4.User._PredicateHelper()._builder())
            for old in oldUsers {
                let sanitizedName = old.username.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                let new = Version5.User(
                    displayName: sanitizedName,
                    email: old.email
                )
                try context.insert(new)
                try context.delete(old)
            }
        },
        didMigrate: nil
    )
}
