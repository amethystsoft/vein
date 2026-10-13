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

#if canImport(SwiftCheck)
    import SwiftCheck
    import Foundation
    import XCTest
    @testable import Vein
    #if TEST_SWIFTUI
        @_spi(VeinTesting) @testable import VeinSwiftUI
    #elseif TEST_SCUI
        @_spi(VeinTesting) @testable import VeinSCUI
    #else
        @_spi(VeinTesting) @testable import VeinCore
    #endif

    final class SwiftCheckOneToOneRelationshipSuite: XCTestCase {
        func testRandomOneToOneOperations() throws {
            let args = CheckerArguments.init(
                maxAllowableSuccessfulTests: ProcessInfo.swiftCheckIterations,
                maxTestCaseSize: 1000
            )

            property("State matches local reference after random operations", arguments: args) <-
                forAll { (ops: [RelationshipOp]) in
                    let owners = [String](repeating: "", count: max(1, ops.count / 50)).map {
                        Owner(name: $0)
                    }
                    let targets = [String](repeating: "", count: max(1, ops.count / 50)).map {
                        Target(name: $0)
                    }

                    let appID = "de.amethystsoft.vein.tests.RandomOneToOne"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for owner in owners {
                        try container.context.insert(owner)
                    }

                    for target in targets {
                        try container.context.insert(target)
                    }

                    for op in ops {
                        try op.perform(on: container, owners: owners, targets: targets)

                        // Compare after EVERY step, so a failure names the operation that broke it.
                        guard try State.matches(container) else {
                            return false <?> "diverged after: \(op)"
                        }
                    }

                    try container.context.save()

                    // Verification using a fresh context to ensure changes are read from db
                    let verificationContainer = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        connection: container.getConnection(),
                        appID: appID,
                        encryptionEnabled: false
                    )

                    if try State.matches(verificationContainer, oldContainer: container) {
                        return true
                    }

                    return false <?> "diverged after save"
                }
        }
    }

    fileprivate enum RelationshipOp: CustomStringConvertible {
        /// Assign a target that is already inserted (and may belong to another owner).
        case setExistingTarget(owner: Int, target: Int)
        /// Assign an owner that is already inserted (and may belong to another target).
        case setExistingOwner(target: Int, owner: Int)

        /// owner.target = nil
        case removeOwner(owner: Int)
        case removeTarget(target: Int)

        /// Move a target to another owner by assigning from the inverse side:
        /// target.owner = newOwner
        case reparentTarget(target: Int, to: Int)
        case reparentOwner(owner: Int, to: Int)

        var description: String {
            switch self {
                case .setExistingTarget(let o, let t): return "setExistingTarget(owner: \(o), target: \(t))"
                case .setExistingOwner(let t, let o): return "setExistingOwner(target: \(t), owner: \(o))"
                case .removeOwner(let o): return "remove(owner: \(o))"
                case .removeTarget(let t): return "removeTarget(target: \(t))"
                case .reparentTarget(let t, let o): return "reparentTarget(target: \(t), to: \(o))"
                case .reparentOwner(let o, let t): return "reparentOwner(owner: \(t), to: \(o))"
            }
        }
    }

    extension RelationshipOp {
        /// Does the operation on the real models, then mirrors it in the reference.
        /// Each case keeps those two steps next to each other on purpose.
        fileprivate func perform(
            on container: ModelContainer,
            owners: [Owner],
            targets: [Target]
        ) throws {
            let count = owners.count
            switch self {
                case .setExistingTarget(let ownerIndex, let targetIndex):
                    let owner = owners[ownerIndex % count]
                    let target = targets[targetIndex % count]

                    owner.target = target

                case .setExistingOwner(let targetIndex, let ownerIndex):
                    let owner = owners[ownerIndex % count]
                    let target = targets[targetIndex % count]

                    owner.target = target

                case .removeTarget(let ownerIndex):
                    let owner = owners[ownerIndex % count]
                    owner.target = nil

                case .removeOwner(let targetIndex):
                    let target = targets[targetIndex % count]
                    target.owner = nil

                case .reparentTarget(let targetIndex, let ownerIndex):
                    let owner = owners[ownerIndex % count]
                    let target = targets[targetIndex % count]

                    target.owner = owner

                case .reparentOwner(let ownerIndex, let targetIndex):
                    let owner = owners[ownerIndex % count]
                    let target = targets[targetIndex % count]

                    owner.target = target
            }
        }
    }

    extension RelationshipOp: Arbitrary {
        fileprivate static var arbitrary: Gen<RelationshipOp> {
            let index = Gen<Int>.sized { size in
                Gen<Int>.choose((0, 100))
            }

            let opChoice = Gen<Int>.choose((0, 5))

            return Gen<RelationshipOp>.compose { gen in
                return switch gen.generate(using: opChoice) {
                    case 0: .setExistingTarget(
                            owner: gen.generate(using: index),
                            target: gen.generate(using: index)
                        )
                    case 1: .setExistingOwner(
                            target: gen.generate(using: index),
                            owner: gen.generate(using: index)
                        )
                    case 2: .reparentTarget(
                            target: gen.generate(using: index),
                            to: gen.generate(using: index)
                        )
                    case 3: .reparentOwner(
                            owner: gen.generate(using: index),
                            to: gen.generate(using: index)
                        )
                    case 4: .removeOwner(owner: gen.generate(using: index))
                    default: .removeTarget(target: gen.generate(using: index))
                }
            }
        }
    }

    fileprivate struct State {
        /// Reads everything back from the container and compares it to this reference.
        static func matches(
            _ container: ModelContainer,
            oldContainer: ModelContainer? = nil
        ) throws -> Bool {
            let realOwners = try container.context.fetchAll(V0_0_1.Owner.self)
            let realTargets = try container.context.fetchAll(V0_0_1.Target.self)

            for owner in realOwners {
                if let target = owner.target, target.owner !== owner { return false }
            }

            for target in realTargets {
                if let owner = target.owner, owner.target !== target { return false }
            }

            // Skip this half if oldContainer wasn't provided
            guard let oldContainer else { return true }

            let inMemoryOwners = try oldContainer.context.fetchAll(V0_0_1.Owner.self)
            let inMemoryTargets = try oldContainer.context.fetchAll(V0_0_1.Target.self)

            guard realOwners.count == inMemoryOwners.count else { return false }
            guard realTargets.count == inMemoryTargets.count else { return false }

            for (index, owner) in inMemoryOwners.enumerated() {
                if realOwners[index].target?.id != owner.target?.id { return false }
            }

            for (index, target) in inMemoryTargets.enumerated() {
                if realTargets[index].owner?.id != target.owner?.id { return false }
            }

            return true
        }
    }

    fileprivate struct MissingModelError: Error {}

    fileprivate enum V0_0_1: VersionedSchema {
        static let version = ModelVersion(0, 0, 1)
        static let models: [any Vein.PersistentModel.Type] = [Owner.self, Target.self]

        @Model
        final class Owner: Identifiable {
            var name: String

            @Relationship(inverse: \Target.owner)
            var target: Target?

            init(name: String) {
                self.name = name
            }
        }

        @Model
        final class Target: Identifiable {
            var name: String

            @Relationship
            var owner: Owner?

            init(name: String) {
                self.name = name
            }
        }
    }

    fileprivate typealias Owner = V0_0_1.Owner
    fileprivate typealias Target = V0_0_1.Target

    extension Owner: Arbitrary {
        fileprivate static var arbitrary: SwiftCheck.Gen<Owner> {
            Gen<Owner>.compose { gen in
                Owner(name: gen.generate())
            }
        }
    }

    extension Target: Arbitrary {
        fileprivate static var arbitrary: SwiftCheck.Gen<Target> {
            Gen<Target>.compose { gen in
                Target(name: gen.generate())
            }
        }
    }

    fileprivate enum Migration: SchemaMigrationPlan {
        static var schemas: [any Vein.VersionedSchema.Type] {
            [V0_0_1.self]
        }

        static var stages: [MigrationStage] {
            []
        }
    }

#endif
