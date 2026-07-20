// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import Foundation
import Testing
import Logging
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUI
#else
    @_spi(VeinTesting) @testable import VeinCore
#endif
@MainActor
@Suite struct RelationshipTest {
    static let logger = Logger(label: "de.amethystsoft.vein.test.relationship")

    @Test func testPersist() async throws {
        let dbPath = try prepareContainerLocation(name: "RelationshipMigration")

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let user = V0_0_1.User(name: "Mia")
        let comment = V0_0_1.Comment(text: "Heyho")

        try container.context.insert(user)
        user.comments.append(comment)
        try container.context.save()

        let oldUsers = try container.context.fetchAll(V0_0_1.User.self)

        #expect(oldUsers.count == 1 && oldUsers.first?.id == user.id)

        let storedSchemas = try container.context.getAllStoredSchemas()

        #expect(
            storedSchemas.sorted() == [
                V0_0_1.User.schema,
                V0_0_1.Comment.schema
            ].sorted()
        )

        // Create new container & trigger migration
        let newContainer = try ModelContainer(
            V0_0_2.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try newContainer.migrate()

        let firstUser = try newContainer.context.fetchAll(V0_0_2.User.self).first
        let firstComment = try newContainer.context.fetchAll(V0_0_2.Comment.self).first

        #expect(firstUser?.is2faEnabled == false)
        #expect(firstUser?.name == "Mia")
        #expect(firstUser?.comments.contains(where: { $0.id == comment.id }) == true)
        #expect(firstComment?.author?.id == user.id)

        let newStoredSchemas = try newContainer.context.getAllStoredSchemas()
        #expect(newStoredSchemas.sorted() == [V0_0_2.User.schema, V0_0_2.Comment.schema].sorted())
    }

    @Test func testOneToManyToManyToManyMigration() async throws {
        let dbPath = try prepareContainerLocation(
            name: "ManyToManyMigration"
        )

        // 1. Initialize V2 DB and seed data
        let container = try ModelContainer(
            V0_0_2.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.ManyToManyTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let user = V0_0_2.User(name: "Mia")
        let comment1 = V0_0_2.Comment(text: "First Comment")
        let comment2 = V0_0_2.Comment(text: "Second Comment")

        try container.context.insert(user)

        user.comments.append(comment1)
        user.comments.append(comment2)
        try container.context.save()

        #expect(user.comments.count == 2)
        #expect(comment1.author?.id == user.id)
        #expect(comment2.author?.id == user.id)

        // 2. Perform Migration by loading V3 Container Schema
        let newContainer = try ModelContainer(
            V0_0_3.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.ManyToManyTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try newContainer.migrate()

        // 3. Verify Many-to-Many integrity on V3
        let migratedUsers = try newContainer.context.fetchAll(
            V0_0_3.User.self
        )
        let migratedComments = try newContainer.context.fetchAll(
            V0_0_3.Comment.self
        )

        #expect(migratedUsers.count == 1)
        #expect(migratedComments.count == 2)

        guard let migratedUser = migratedUsers.first else {
            Issue.record("Target user not migrated.")
            return
        }

        #expect(migratedUser.name == "Mia")
        #expect(migratedUser.comments.count == 2)

        // Verify relationships point back bidirectionally
        for comment in migratedComments {
            #expect(comment.authors.contains(where: { $0.id == migratedUser.id }))
        }
    }

    func prepareContainerLocation(name: String) throws -> String {
        let containerPath = FileManager.default.temporaryDirectory

        let dbDir = containerPath.relativePath.appending("/veinTests/\(testID.uuidString)")

        let dbPath = dbDir.appending("/\(name).sqlite3")

        try FileManager.default.createDirectory(
            atPath: dbDir,
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: dbPath) {
            FileManager.default.createFile(
                atPath: dbPath,
                contents: nil
            )
        }

        return dbPath
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self, Comment.self]

    @Model
    final class User: Identifiable {
        @Field
        var name: String

        @Relationship(inverse: \Comment.author)
        var comments: [Comment]

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Comment: Identifiable {
        @Relationship
        var author: User?

        @Field
        var text: String

        init(text: String) {
            self.text = text
        }
    }
}

fileprivate enum V0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 2)
    static let models: [any Vein.PersistentModel.Type] = [User.self, Comment.self]

    @Model
    final class User: Identifiable {
        @Field
        var name: String

        @Relationship(inverse: \Comment.author)
        var comments: [Comment]

        @Field
        var is2faEnabled: Bool = false

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Comment: Identifiable {
        @Relationship
        var author: User?

        @Field
        var text: String

        init(text: String) {
            self.text = text
        }
    }
}

// MARK: - V3 Schema: Many-to-Many
fileprivate enum V0_0_3: VersionedSchema {
    static let version = ModelVersion(0, 0, 3)
    static let models: [any Vein.PersistentModel.Type] = [
        User.self,
        Comment.self
    ]

    @Model
    final class User: Identifiable {
        @Field
        var name: String

        @Field
        var is2faEnabled: Bool = false

        @Relationship(inverse: \Comment.authors)
        var comments: [Comment]

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Comment: Identifiable {
        // Migration target: changed from author: User? to authors: [User]
        @Relationship
        var authors: [User]

        @Field
        var text: String

        init(text: String) {
            self.text = text
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self, V0_0_2.self, V0_0_3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2ToV3]
    }

    static let migrateV1toV2 = MigrationStage.complex(
        fromVersion: V0_0_1.self,
        toVersion: V0_0_2.self,
        willMigrate: { context in
            // 1. Fetch all old models independently to avoid dynamic graph changes
            let oldUsers = try context.fetchAll(V0_0_1.User.self)
            let oldComments = try context.fetchAll(V0_0_1.Comment.self)

            // 2. Map old comments to new comments
            var newCommentsMap: [ULID: V0_0_2.Comment] = [:]
            for oldComment in oldComments {
                let newComment = V0_0_2.Comment(text: oldComment.text)
                newComment.id = oldComment.id
                newCommentsMap[oldComment.id] = newComment
            }

            // 3. Map users and link their comments
            for oldUser in oldUsers {
                let newUser = V0_0_2.User(name: oldUser.name)
                newUser.id = oldUser.id
                try context.insert(newUser)
                newUser.comments = oldUser.comments.compactMap { oldComment in
                    newCommentsMap[oldComment.id]
                }
            }

            // 4. Safely delete all old records
            for oldComment in oldComments {
                try context.delete(oldComment)
            }
            for oldUser in oldUsers {
                try context.delete(oldUser)
            }
        },
        didMigrate: nil
    )

    static let migrateV2ToV3 = MigrationStage.complex(
        fromVersion: V0_0_2.self,
        toVersion: V0_0_3.self,
        willMigrate: { context in
            let oldUsers = try context.fetchAll(V0_0_2.User.self)
            let oldComments = try context.fetchAll(V0_0_2.Comment.self)

            // 1. Maintain transient map of converted Users
            var newUsersMap: [ULID: V0_0_3.User] = [:]
            for oldUser in oldUsers {
                let newUser = V0_0_3.User(name: oldUser.name)
                newUser.id = oldUser.id
                newUser.is2faEnabled = oldUser.is2faEnabled
                try context.insert(newUser)
                newUsersMap[oldUser.id] = newUser
            }

            // 2. Convert old Comments + link their migrated parents
            for oldComment in oldComments {
                let newComment = V0_0_3.Comment(text: oldComment.text)
                newComment.id = oldComment.id
                try context.insert(newComment)

                // Map the old singular parent into the new Many-to-Many array
                if let oldAuthor = oldComment.author,
                   let newUser = newUsersMap[oldAuthor.id]
                {
                    newComment.authors.append(newUser)
                }
            }

            // 3. Clear the legacy instances safely
            for oldComment in oldComments {
                try context.delete(oldComment)
            }
            for oldUser in oldUsers {
                try context.delete(oldUser)
            }
        },
        didMigrate: nil
    )
}
