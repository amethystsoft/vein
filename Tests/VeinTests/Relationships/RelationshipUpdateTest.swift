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
    @testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
    @testable import VeinCore
#endif

@MainActor
extension RelationshipTest {
    @Test func testUpdate() async throws {
        let dbPath = try prepareContainerLocation(name: "RelationshipUpdate")

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

        #expect(user.comments.contains { $0.id == comment.id })
        #expect(user.context != nil)
        #expect(comment.context?.identifier == user.context?.identifier)
        #expect(comment.author?.id == user.id)

        // Work with new context to make sure we read from disk.
        let newContainer = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        guard
            let fetchedUser = try newContainer.context.fetchAll(V0_0_1.User.self).first,
            let fetchedComment = try newContainer.context.fetchAll(V0_0_1.Comment.self).first
        else {
            Issue.record("Unexpectedly found empty results")
            return
        }

        #expect(fetchedUser.comments.contains { $0.id == comment.id })
        #expect(fetchedComment.author?.id == user.id)
    }

    @Test func testReParenting() async throws {
        let dbPath = try prepareContainerLocation(name: "RelationshipRe-Parent")

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let userA = V0_0_1.User(name: "Mia")
        let userB = V0_0_1.User(name: "John")
        let comment = V0_0_1.Comment(text: "Transferable post")

        try container.context.insert(userA)
        try container.context.insert(userB)
        userA.comments.append(comment)
        try container.context.save()

        // Transfer relationship
        comment.author = userB
        try container.context.save()

        #expect(userA.comments.isEmpty)
        #expect(userB.comments.map(\.id).contains(comment.id))
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

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }

    static var stages: [MigrationStage] {[]}
}
