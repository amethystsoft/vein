import Foundation
import VeinCore

fileprivate enum Version1: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        User.self,
        Profile.self
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
        User.self,
        Profile.self
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
        User.self,
        Profile.self,
        Post.self
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

fileprivate enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self,
        Version2.self,
        Version3.self
    ]}
    
    static var stages: [Vein.MigrationStage] {[
        v1ToV2,
        v2ToV3,
    ]}
    
    static let v1ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version1.self,
        toVersion: Version2.self,
        willMigrate: { context in
            try Version1.User.fieldsAddedMigration(to: Version2.User.self, on: context)
            try Version1.Profile.unchangedMigration(to: Version2.Profile.self, on: context)
        },
        didMigrate: nil
    )
    
    static let v2ToV3 = Vein.MigrationStage.complex(
        fromVersion: Version2.self,
        toVersion: Version3.self,
        willMigrate: { context in
            // Basic migrations
            try Version2.User.unchangedMigration(to: Version3.User.self, on: context)
            
            // Logic migration for Profile
            let oldProfiles = try context.fetchAll(Version2.Profile.self)
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
}
