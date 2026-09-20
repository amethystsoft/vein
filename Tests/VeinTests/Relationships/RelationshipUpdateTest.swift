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
            connection: container.getConnection(),
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

    @Test
    func `update revives deallocated other side`() async throws {
        let dbPath = try prepareContainerLocation(name: "RelationshipRevivesOtherSide")

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

        #expect(comment.author?.name == "Mia")

        container.context.identityMap.setToNil(
            type: V0_0_1.Comment.typeIdentifier,
            id: comment.id
        )

        userA.comments.removeAll()

        let newComment = try #require(container.context.identityMap.getTracked(
            V0_0_1.Comment.self,
            id: comment.id
        ))

        #expect(newComment.author == nil)
        #expect(ObjectIdentifier(comment) != ObjectIdentifier(newComment))
        #expect(newComment.id == comment.id)

        let oldCommentState = comment.extractPrimitiveState()
        #expect(oldCommentState.values["author"] as? ULID == userA.id)
    }

    @Test
    func `duplicates are allowed for array relationships`() async throws {
        let dbPath = try prepareContainerLocation(name: "RelationshipArrayAllowsDuplicates")

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let userA = V0_0_1.User(name: "Mia")
        let comment = V0_0_1.Comment(text: "Transferable post")

        try container.context.insert(userA)
        userA.comments.append(comment)
        userA.comments.append(comment)
        try container.context.save()

        let commentIDs = userA.extractPrimitiveState().values["comments"]
        #expect((commentIDs as? [ULID])?.count == 2)
    }

    @Test
    func `removing one duplicate only removes one from the other side post remove`() async throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_2.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let post = V0_0_2.Post(title: "Vein 1.0")
        let tag = V0_0_2.Tag(name: "Swift")

        try container.context.insert(post)
        post.tags.append(tag)
        post.tags.append(tag)

        let tagIDs = post.extractPrimitiveState().values["tags"]
        #expect((tagIDs as? [ULID])?.count == 2)
        #expect(post.tags.count == 2)

        let postIDs = tag.extractPrimitiveState().values["posts"]
        #expect((postIDs as? [ULID])?.count == 2)
        #expect(tag.posts.count == 2)

        post.tags.remove(at: 0)

        let newTagIDs = post.extractPrimitiveState().values["tags"]
        #expect((newTagIDs as? [ULID])?.count == 1)
        #expect(post.tags.count == 1)

        let newPostIDs = tag.extractPrimitiveState().values["posts"]
        #expect((newPostIDs as? [ULID])?.count == 1)
        #expect(tag.posts.count == 1)
    }

    @Test
    func `removing one duplicate only removes one from the other side tags remove`() async throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_2.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let post = V0_0_2.Post(title: "Vein 1.0")
        let tag = V0_0_2.Tag(name: "Swift")

        try container.context.insert(post)
        post.tags.append(tag)
        post.tags.append(tag)

        let tagIDs = post.extractPrimitiveState().values["tags"]
        #expect((tagIDs as? [ULID])?.count == 2)
        #expect(post.tags.count == 2)

        let postIDs = tag.extractPrimitiveState().values["posts"]
        #expect((postIDs as? [ULID])?.count == 2)
        #expect(tag.posts.count == 2)

        tag.posts.remove(at: 0)

        let newTagIDs = post.extractPrimitiveState().values["tags"]
        #expect((newTagIDs as? [ULID])?.count == 1)
        #expect(post.tags.count == 1)

        let newPostIDs = tag.extractPrimitiveState().values["posts"]
        #expect((newPostIDs as? [ULID])?.count == 1)
        #expect(tag.posts.count == 1)
    }

    @Test
    func `removing one from many side should keep one relationship alive if Relationships are remaining`(
    ) async throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let userA = V0_0_1.User(name: "Mia")
        let comment = V0_0_1.Comment(text: "Transferable post")

        try container.context.insert(userA)
        userA.comments.append(comment)
        userA.comments.append(comment)
        try container.context.save()

        let commentIDs = userA.extractPrimitiveState().values["comments"]
        #expect((commentIDs as? [ULID])?.count == 2)
        #expect(userA.comments.count == 2)
        #expect(comment.author === userA)

        userA.comments.remove(at: 0)

        let newCommentIDs = userA.extractPrimitiveState().values["comments"]
        #expect((newCommentIDs as? [ULID])?.count == 1)
        #expect(userA.comments.count == 1)
        #expect(comment.author === userA)

        userA.comments.remove(at: 0)

        let nextCommentIDs = userA.extractPrimitiveState().values["comments"]
        #expect((nextCommentIDs as? [ULID])?.count == 0)
        #expect(userA.comments.count == 0)
        #expect(comment.author == nil)
    }

    @Test
    func `removing OneRelationship should remove all of type from ManyRelationship`() async throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let userA = V0_0_1.User(name: "Mia")
        let comment = V0_0_1.Comment(text: "Transferable post")

        try container.context.insert(userA)
        userA.comments.append(comment)
        userA.comments.append(comment)
        try container.context.save()

        let commentIDs = userA.extractPrimitiveState().values["comments"]
        #expect((commentIDs as? [ULID])?.count == 2)
        #expect(userA.comments.count == 2)
        #expect(comment.author === userA)

        comment.author = nil

        let nextCommentIDs = userA.extractPrimitiveState().values["comments"]
        #expect((nextCommentIDs as? [ULID])?.count == 0)
        #expect(userA.comments.count == 0)
        #expect(comment.author == nil)
    }

    @Test
    func `reparenting OneRelationship should remove all of type from ManyRelationship`(
    ) async throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let userA = V0_0_1.User(name: "Mia")
        let userB = V0_0_1.User(name: "Skyla")
        let comment = V0_0_1.Comment(text: "Transferable post")

        try container.context.insert(userA)
        try container.context.insert(userB)
        userA.comments.append(comment)
        userA.comments.append(comment)
        try container.context.save()

        let commentIDs = userA.extractPrimitiveState().values["comments"]
        #expect((commentIDs as? [ULID])?.count == 2)
        #expect(userA.comments.count == 2)
        #expect(comment.author === userA)

        comment.author = userB

        let nextCommentIDsA = userA.extractPrimitiveState().values["comments"]
        let nextCommentIDsB = userB.extractPrimitiveState().values["comments"]
        #expect((nextCommentIDsA as? [ULID])?.count == 0)
        #expect((nextCommentIDsB as? [ULID])?.count == 1)
        #expect(userA.comments.count == 0)
        #expect(userB.comments.count == 1)
        #expect(comment.author === userB)
    }

    @Test
    func `adding already parented OneRelationship to new many Relationship reparents it`(
    ) async throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let userA = V0_0_1.User(name: "Mia")
        let userB = V0_0_1.User(name: "Skyla")
        let comment = V0_0_1.Comment(text: "Transferable post")

        try container.context.insert(userA)
        try container.context.insert(userB)
        userA.comments.append(comment)
        userA.comments.append(comment)
        try container.context.save()

        let commentIDs = userA.extractPrimitiveState().values["comments"]
        #expect((commentIDs as? [ULID])?.count == 2)
        #expect(userA.comments.count == 2)
        #expect(comment.author === userA)

        userB.comments.append(comment)

        let nextCommentIDsA = userA.extractPrimitiveState().values["comments"]
        let nextCommentIDsB = userB.extractPrimitiveState().values["comments"]
        #expect((nextCommentIDsA as? [ULID])?.count == 0)
        #expect((nextCommentIDsB as? [ULID])?.count == 1)
        #expect(userA.comments.count == 0)
        #expect(userB.comments.count == 1)
        #expect(comment.author === userB)
    }

    @Test
    func `removing multiple leaves correct result`() async throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_2.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let post = V0_0_2.Post(title: "Vein 1.0")
        let tag = V0_0_2.Tag(name: "Swift")

        try container.context.insert(post)
        post.tags.append(tag)
        post.tags.append(tag)
        post.tags.append(tag)
        post.tags.append(tag)
        post.tags.append(tag)
        try container.context.save()

        let tagIDs = post.extractPrimitiveState().values["tags"]
        let postIDs = tag.extractPrimitiveState().values["posts"]
        #expect((tagIDs as? [ULID])?.count == 5)
        #expect((postIDs as? [ULID])?.count == 5)
        #expect(post.tags.count == 5)
        #expect(tag.posts.count == 5)

        post.tags.removeFirst(3)

        let newTagIDs = post.extractPrimitiveState().values["tags"]
        let newPostIDs = tag.extractPrimitiveState().values["posts"]
        #expect((newTagIDs as? [ULID])?.count == 2)
        #expect((newPostIDs as? [ULID])?.count == 2)
        #expect(post.tags.count == 2)
        #expect(tag.posts.count == 2)
    }

    @Test
    func `deletion removes all references`() async throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_2.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let postA = V0_0_2.Post(title: "Vein 1.0")
        let postB = V0_0_2.Post(title: "Vein 1.1")
        let tag = V0_0_2.Tag(name: "Swift")

        try container.context.insert(postA)
        try container.context.insert(postB)
        postA.tags.append(tag)
        postA.tags.append(tag)
        postB.tags.append(tag)
        postB.tags.append(tag)

        try container.context.save()

        let tagIDsA = postA.extractPrimitiveState().values["tags"]
        let tagIDsB = postB.extractPrimitiveState().values["tags"]
        let postIDs = tag.extractPrimitiveState().values["posts"]
        #expect((tagIDsA as? [ULID])?.count == 2)
        #expect(postA.tags.count == 2)
        #expect((tagIDsB as? [ULID])?.count == 2)
        #expect(postB.tags.count == 2)
        #expect((postIDs as? [ULID])?.count == 4)

        try container.context.delete(tag)

        let nextTagIDsA = postA.extractPrimitiveState().values["tags"]
        let nextTagIDsB = postB.extractPrimitiveState().values["tags"]
        let nextPostIDs = tag.extractPrimitiveState().values["posts"]
        #expect((nextTagIDsA as? [ULID])?.count == 0)
        #expect(postA.tags.count == 0)
        #expect((nextTagIDsB as? [ULID])?.count == 0)
        #expect(postB.tags.count == 0)
        #expect((nextPostIDs as? [ULID])?.count == 0)
    }

    @Test("Reparenting OneRelationship removes other side")
    func reparentingOneRelationshipRemovesOtherSide() throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_3.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let parentA = V0_0_3.Parent(name: "A")
        let parentB = V0_0_3.Parent(name: "B")
        let child = V0_0_3.Child(name: "Springer nach E5")

        try container.context.insert(parentA)
        try container.context.insert(parentB)

        parentA.child = child
        #expect(parentA.child === child)
        #expect(child.parent === parentA)
        #expect(parentA.extractPrimitiveState().values["child"] as? ULID? == child.id)
        #expect(child.extractPrimitiveState().values["parent"] as? ULID? == parentA.id)

        parentB.child = child
        #expect(parentB.child === child)
        #expect(child.parent === parentB)
        #expect(parentB.extractPrimitiveState().values["child"] as? ULID? == child.id)
        #expect(child.extractPrimitiveState().values["parent"] as? ULID? == parentB.id)
        #expect(parentA.child == nil)
        #expect(parentA.extractPrimitiveState().values["child"] as? ULID? == nil)
    }

    @Test("Reparenting OneRelationship removes other side with previous relationship")
    func reparentingOneRelationshipRemovesOtherSideWithPreviousRelationship() throws {
        let dbPath =
            try prepareContainerLocation(
                name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
            )

        let container = try ModelContainer(
            V0_0_3.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let parentA = V0_0_3.Parent(name: "A")
        let parentB = V0_0_3.Parent(name: "B")
        let child = V0_0_3.Child(name: "Springer nach E5")
        let child2 = V0_0_3.Child(name: "Springer nach E5")

        try container.context.insert(parentA)
        try container.context.insert(parentB)

        parentA.child = child
        parentB.child = child2
        #expect(parentA.child === child)
        #expect(child.parent === parentA)
        #expect(parentB.child === child2)
        #expect(child2.parent === parentB)
        #expect(parentA.extractPrimitiveState().values["child"] as? ULID? == child.id)
        #expect(child.extractPrimitiveState().values["parent"] as? ULID? == parentA.id)
        #expect(parentB.extractPrimitiveState().values["child"] as? ULID? == child2.id)
        #expect(child2.extractPrimitiveState().values["parent"] as? ULID? == parentB.id)

        parentB.child = child
        #expect(parentB.child === child)
        #expect(child.parent === parentB)
        #expect(parentB.extractPrimitiveState().values["child"] as? ULID? == child.id)
        #expect(child.extractPrimitiveState().values["parent"] as? ULID? == parentB.id)
        #expect(parentA.child == nil)
        #expect(child2.parent == nil)
        #expect(parentA.extractPrimitiveState().values["child"] as? ULID? == nil)
        #expect(child2.extractPrimitiveState().values["parent"] as? ULID? == nil)
    }
    
    @Test("Reparenting OneRelationship removes other side with previous relationship many relationship")
    func reparentingOneRelationshipRemovesOtherSideWithPreviousRelationshipManyRelationship() throws {
        let dbPath =
        try prepareContainerLocation(
            name: "RelationshipRemovingOneDuplicateOnlyRemovesOneFromOtherSide"
        )
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        let parentA = V0_0_1.Comment(text: "A")
        let parentB = V0_0_1.Comment(text: "B")
        let child = V0_0_1.User(name: "Springer nach E5")
        let child2 = V0_0_1.User(name: "Springer nach E5")
        
        try setup()
        try container.context.save()
        try verify()
        
        func setup() throws {
            try container.context.insert(parentA)
            try container.context.insert(parentB)
            
            parentA.author = child
            parentB.author = child2
            #expect(parentA.author === child)
            #expect(child.comments.contains { $0 === parentA })
            #expect(parentB.author === child2)
            #expect(child2.comments.contains { $0 === parentB })
            #expect(parentA.extractPrimitiveState().values["author"] as? ULID? == child.id)
            #expect(child.extractPrimitiveState().values["comments"] as? [ULID] == [parentA.id])
            #expect(parentB.extractPrimitiveState().values["author"] as? ULID? == child2.id)
            #expect(child2.extractPrimitiveState().values["comments"] as? [ULID] == [parentB.id])
            
            parentB.author = child
            #expect(parentB.author === child)
            #expect(child.comments.contains { $0 === parentB })
            #expect(parentA.author === child)
            #expect(child2.comments.isEmpty)
            #expect(parentB.extractPrimitiveState().values["author"] as? ULID? == child.id)
            #expect((child.extractPrimitiveState().values["comments"] as? [ULID])?.sorted() == [parentB.id, parentA.id].sorted())
            #expect(parentA.extractPrimitiveState().values["author"] as? ULID? == child.id)
            #expect(child2.extractPrimitiveState().values["comments"] as? [ULID] == [])
        }
        
        func verify() throws {
            let newContainer = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                connection: container.getConnection(),
                appID: "de.amethystsoft.vein.RelationshipTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            
            let users = try newContainer.context.fetchAll(V0_0_1.User.self)
            let user1 = try #require(users.first { $0.id == child.id })
            let user2 = try #require(users.first { $0.id == child2.id })
            
            let comments = try newContainer.context.fetchAll(V0_0_1.Comment.self)
            let commentA = try #require(comments.first { $0.id == parentA.id })
            let commentB = try #require(comments.first { $0.id == parentB.id })
            
            #expect(commentB.author === user1)
            #expect(user1.comments.contains { $0 === commentB })
            #expect(commentA.author === user1)
            #expect(user2.comments.isEmpty)
            #expect(commentB.extractPrimitiveState().values["author"] as? ULID? == user1.id)
            #expect((user1.extractPrimitiveState().values["comments"] as? [ULID])?.sorted() == [commentB.id, commentA.id].sorted())
            #expect(commentA.extractPrimitiveState().values["author"] as? ULID? == user1.id)
            #expect(user2.extractPrimitiveState().values["comments"] as? [ULID] == [])
        }
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

fileprivate enum V0_0_3: VersionedSchema {
    static let version = ModelVersion(0, 0, 3)
    static let models: [any Vein.PersistentModel.Type] = [Parent.self, Child.self]

    @Model
    final class Parent: Identifiable {
        @Field
        var name: String

        @Relationship(inverse: \Child.parent)
        var child: Child?

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Child: Identifiable {
        @Relationship
        var parent: Parent?

        @Field
        var name: String

        init(name: String) {
            self.name = name
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self, V0_0_2.self, V0_0_3.self]
    }

    static var stages: [MigrationStage] {[]}
}
