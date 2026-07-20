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

extension RelationshipTest {
    // Example Schema: Tag (inverse: "posts") <-> Post (inverse: "tags")
    @Test func testManyToManyInsertAndClear() async throws {
        let dbPath = try prepareContainerLocation(name: "ManyManyInsertAndClear")

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let post = V0_0_1.Post(title: "Swift Optimization")
        let tagSwift = V0_0_1.Tag(name: "Swift")
        let tagPerformance = V0_0_1.Tag(name: "Performance")

        try container.context.insert(post)
        post.tags.append(contentsOf: [tagSwift, tagPerformance])
        try container.context.save()

        #expect(tagSwift.posts.contains(where: { $0.id == post.id }))

        try verifySaveWithNewContainer()

        // Verify removal clean-up
        post.tags.remove(at: 0)
        try container.context.save()
        #expect(tagSwift.posts.isEmpty)
        #expect(tagPerformance.posts.contains(where: { $0.id == post.id }))

        try verifyRemovalWithNewContainer()

        func verifySaveWithNewContainer() throws {
            // Verify disk written changes
            let newContainer = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: dbPath,
                appID: "de.amethystsoft.vein.RelationshipTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )

            guard
                let fetchedPost = try newContainer.context.fetchAll(V0_0_1.Post.self).first
            else {
                Issue.record("Unexpectedly found no posts")
                return
            }

            #expect(fetchedPost.tags
                .contains { $0.id == tagSwift.id || $0.id == tagPerformance.id })
        }

        func verifyRemovalWithNewContainer() throws {
            let newContainer = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: dbPath,
                appID: "de.amethystsoft.vein.RelationshipTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )

            guard
                let fetchedPost = try newContainer.context.fetchAll(V0_0_1.Post.self).first,
                let swiftTag = try newContainer.context.fetchAll(#Predicate<V0_0_1.Tag> { tag in
                    tag.name == "Swift"
                }).first
            else {
                Issue.record("Unexpectedly found no posts")
                return
            }

            #expect(fetchedPost.tags.contains { $0.id == tagPerformance.id } )
            #expect(!fetchedPost.tags.contains { $0.id == tagSwift.id } )
            #expect(swiftTag.posts.isEmpty)
        }
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Tag.self, Post.self]

    @Model
    final class Tag: Identifiable {
        @Field
        var name: String

        @Relationship(inverse: \Post.tags)
        var posts: Array<Post>

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Post: Identifiable {
        @Relationship
        var tags: Array<Tag>

        @Field
        var title: String

        init(title: String) {
            self.title = title
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }

    static var stages: [MigrationStage] {[]}
}
