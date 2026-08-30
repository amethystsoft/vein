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
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUI
#else
    @_spi(VeinTesting) @testable import VeinCore
#endif

struct MultithreadedStressTests {
    @Test(arguments: [true, false])
    func identityMapReturnsSameInstanceAcrossThreads(_ save: Bool = true) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.identity",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let model = V0_0_1.Person(name: "Mia", email: "mia@example.com")
        try container.context.insert(model)
        if save {
            try container.context.save()
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let fetched = try container.context.fetchAll(V0_0_1.Person.self)
                    guard let first = fetched.first else { return }
                    #expect(first === model)
                }
            }
            try await group.waitForAll()
        }
    }

    @Test(arguments: [true, false])
    func concurrentInsertAndFetch(_ save: Bool = true) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.insertfetch",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let person = V0_0_1.Person(name: "Person \(i)", email: "person\(i)@example.com")
                    try container.context.insert(person)
                    if save {
                        try container.context.save()
                    }
                }
            }

            for _ in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let results = try container.context.fetchAll(V0_0_1.Person.self)
                    #expect(results.count <= 100)
                }
            }

            try await group.waitForAll()
        }

        let finalResults = try container.context.fetchAll(V0_0_1.Person.self)
        #expect(finalResults.count == 100)

        for i in 0..<100 {
            #expect(
                finalResults
                    .contains {
                        $0.email == "person\(i)@example.com"
                            && $0.name == "Person \(i)"
                    }
            )
        }
    }

    @Test(arguments: [true, false])
    func concurrentFilterAndSort(_ save: Bool = true) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.filtersort",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try container.context.insert(V0_0_1.Person(name: "Alice", email: "alice@example.com"))
        try container.context.insert(V0_0_1.Person(name: "Bob", email: "bob@example.com"))
        if save {
            try container.context.save()
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let results = try container.context
                        .fetchAll(#Predicate<V0_0_1.Person> { person in
                            person.name == "Alice"
                        })
                    #expect(results.count == 1)
                }
            }

            for _ in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let results = try container.context.fetchAll(
                        V0_0_1.Person.self,
                        sortBy: [SortRule(\.name)]
                    )
                    #expect(results.count == 2)
                }
            }

            try await group.waitForAll()
        }
    }

    @Test(arguments: [true, false])
    func mixedReadWriteSameModel(_ save: Bool = true) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.mixed",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let model = V0_0_1.Person(name: "Original", email: "original@example.com")
        try container.context.insert(model)

        if save {
            try container.context.save()
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    model.name = "Updated \(i)"
                    if save {
                        try container.context.save()
                    }
                }
            }

            for _ in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let fetched = try container.context.fetchAll(V0_0_1.Person.self)
                    guard let first = fetched.first else { return }

                    // Both are valid as read write order is non deterministic.
                    #expect(first.name == "Original" || first.name.hasPrefix("Updated"))
                }
            }

            try await group.waitForAll()
        }

        #expect(model.name.hasPrefix("Updated"))
    }

    @Test(arguments: [true, false])
    func concurrentIdentityMapAccess(_ save: Bool = true) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.idmap",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        for i in 0..<50 {
            let p = V0_0_1.Person(name: "Person \(i)", email: "p\(i)@example.com")
            try container.context.insert(p)
        }

        if save {
            try container.context.save()
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    _ = container.context.trackedObjectCount
                    _ = container.context.identityMap.getAll(of: V0_0_1.Person.self)
                    _ = try container.context.fetchAll(V0_0_1.Person.self)
                }
            }
            try await group.waitForAll()
        }
    }

    @Test(arguments: [true, false])
    func concurrentLazyFieldReadWrite(_ save: Bool) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.lazy",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let model = V0_0_1.Person(name: "Mia", email: "mia@example.com")
        try container.context.insert(model)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    _ = model.notes
                    model.notes = "Note \(i)"
                }
            }
            try await group.waitForAll()
        }

        if save {
            try container.context.save()
        }
        let fetched = try container.context.fetchAll(V0_0_1.Person.self).first
        #expect(fetched?.notes?.hasPrefix("Note ") == true)
    }

    @Test(arguments: [true, false])
    func concurrentOneToOneRelationship(_ save: Bool) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.oneToOne",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let person = V0_0_1.Person(name: "Person \(i)", email: "person\(i)@example.com")
                    let profile = V0_0_1.Profile(bio: "Bio \(i)")
                    try container.context.insert(person)
                    try container.context.insert(profile)
                    person.profile = profile
                }
            }
            try await group.waitForAll()
        }

        if save {
            try container.context.save()
        }

        let people = try container.context.fetchAll(V0_0_1.Person.self)
        let profiles = try container.context.fetchAll(V0_0_1.Profile.self)
        #expect(people.count == 50)
        #expect(profiles.count == 50)
        #expect(people.allSatisfy { $0.profile != nil })
    }

    @Test(arguments: [true, false])
    func concurrentOneToManyRelationship(_ save: Bool) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.oneToMany",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let post = V0_0_1.Post(title: "Post \(i)")
                    let comment = V0_0_1.Comment(text: "Comment \(i)")
                    try container.context.insert(post)
                    try container.context.insert(comment)
                    post.comments.append(comment)
                }
            }
            try await group.waitForAll()
        }

        if save {
            try container.context.save()
        }

        let posts = try container.context.fetchAll(V0_0_1.Post.self)
        let comments = try container.context.fetchAll(V0_0_1.Comment.self)
        #expect(posts.count == 50)
        #expect(comments.count == 50)
        #expect(posts.allSatisfy { $0.comments.count == 1 })
    }

    @Test(arguments: [true, false])
    func concurrentManyToManyRelationship(_ save: Bool) async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded.manyToMany",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let post = V0_0_1.Post(title: "Post \(i)")
                    let tag = V0_0_1.Tag(name: "Tag \(i)")
                    try container.context.insert(post)
                    try container.context.insert(tag)
                    post.tags.append(tag)
                }
            }
            try await group.waitForAll()
        }

        try container.context.save()

        let posts = try container.context.fetchAll(V0_0_1.Post.self)
        let tags = try container.context.fetchAll(V0_0_1.Tag.self)
        #expect(posts.count == 50)
        #expect(tags.count == 50)
        #expect(posts.allSatisfy { $0.tags.count == 1 })
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [
        Person.self,
        Profile.self,
        Post.self,
        Comment.self,
        Tag.self
    ]

    @Model
    final class Person: Identifiable {
        @Field var name: String
        @Field var email: String
        @LazyField var notes: String?
        @Relationship(inverse: \Profile.person) var profile: Profile?
        init(name: String, email: String) {
            self.name = name
            self.email = email
        }
    }

    @Model
    final class Profile: Identifiable {
        @Field var bio: String
        @Relationship var person: Person?
        init(bio: String) {
            self.bio = bio
        }
    }

    @Model
    final class Post: Identifiable {
        @Relationship var tags: [Tag]
        @Relationship(inverse: \Comment.post) var comments: [Comment]
        @Field var title: String
        init(title: String) {
            self.title = title
        }
    }

    @Model
    final class Comment: Identifiable {
        @Relationship var post: Post?
        @Field var text: String
        init(text: String) {
            self.text = text
        }
    }

    @Model
    final class Tag: Identifiable {
        @Field var name: String
        init(name: String) {
            self.name = name
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] { [V0_0_1.self] }
    static var stages: [MigrationStage] { [] }
}
