// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import Foundation
import Testing
@testable import Vein
#if TEST_SWIFTUI
    @testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
    @testable import VeinCore
#endif

struct MultithreadedTest {
    @Test
    func run() async throws {
        let container = try ModelContainer(
            Version1.self,
            migration: MigrationPlan.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    let model = Version1.Task(name: "Task \(i)")
                    model.text = "Test \(i)"
                    try container.context.insert(model)
                    try container.context.save()

                    _ = try container.context.fetchAll(Version1.Task.self)
                }
            }

            try await group.waitForAll()
        }

        let newContainer = try ModelContainer(
            Version1.self,
            migration: MigrationPlan.self,
            connection: container.getConnection(),
            appID: "de.amethystsoft.vein.tests.multithreaded",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let tasks = try newContainer.context.fetchAll(Version1.Task.self)
        #expect(tasks.count == 100)
        #expect(tasks.allSatisfy { $0.text?.hasPrefix("Test ") == true })
    }

    @Test
    func multithreadedLazyFieldReadWrite() async throws {
        let container = try ModelContainer(
            Version1.self,
            migration: MigrationPlan.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let model = Version1.Task(name: "Test")
        try container.context.insert(model)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    _ = model.text
                    model.text = "Test \(i)"
                    try container.context.save()
                }
            }

            try await group.waitForAll()
        }

        let newContainer = try ModelContainer(
            Version1.self,
            migration: MigrationPlan.self,
            connection: container.getConnection(),
            appID: "de.amethystsoft.vein.tests.multithreaded",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        guard let result = try newContainer.context.fetchAll(Version1.Task.self).first else {
            Issue.record("Unexpectedly no result for Version1.Task")
            return
        }
        #expect(result.text?.hasPrefix("Test ") == true)
    }

    @Test
    func multithreadedFieldReadWrite() async throws {
        let container = try ModelContainer(
            Version1.self,
            migration: MigrationPlan.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.multithreaded",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let model = Version1.Task(name: "Base")
        try container.context.insert(model)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000...50_000))
                    _ = model.name
                    model.name = "Test \(i)"
                    try container.context.save()
                }
            }

            try await group.waitForAll()
        }

        let newContainer = try ModelContainer(
            Version1.self,
            migration: MigrationPlan.self,
            connection: container.getConnection(),
            appID: "de.amethystsoft.vein.tests.multithreaded",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        guard let result = try newContainer.context.fetchAll(Version1.Task.self).first else {
            Issue.record("Unexpectedly no result for Version1.Task")
            return
        }
        #expect(result.name.hasPrefix("Test"))
    }
}

fileprivate enum Version1: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)
    static var models: [any Vein.PersistentModel.Type] {[
        Task.self
    ]}

    @Model
    final class Task {
        @Field var name: String
        @LazyField var text: String?

        init(name: String) { self.name = name }
    }
}

fileprivate enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {[
        Version1.self
    ]}

    static var stages: [Vein.MigrationStage] {[]}
}
