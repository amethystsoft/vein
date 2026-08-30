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
            #expect(finalResults.contains { $0.email == "person\(i)@example.com" && $0.name == "Person \(i)"})
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
                    let results = try container.context.fetchAll(#Predicate<V0_0_1.Person> { person in
                        person.name == "Alice"
                    })
                    #expect(results.count == 1)
                }
            }

            for _ in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let results = try container.context.fetchAll(V0_0_1.Person.self, sortBy: [SortRule(\.name)])
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
                    #expect(first.name.hasPrefix("Updated"))
                }
            }

            try await group.waitForAll()
        }
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
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Person.self, Post.self, Tag.self]

    @Model
    final class Person: Identifiable {
        @Field var name: String
        @Field var email: String
        init(name: String, email: String) {
            self.name = name
            self.email = email
        }
    }

    @Model
    final class Post: Identifiable {
        @Relationship var tags: [Tag]
        @Field var title: String
        init(title: String) {
            self.title = title
            self.tags = []
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
