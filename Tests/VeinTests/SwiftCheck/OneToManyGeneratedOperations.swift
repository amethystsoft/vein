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

    final class SwiftCheckOneToManyRelationshipSuite: XCTestCase {
        static let modelAmount = 5
        // Scope: verify there's always a state that makes sense
        func testRandomOneToManyOperations() throws {
            let args = CheckerArguments.init(
                maxAllowableSuccessfulTests: ProcessInfo.swiftCheckIterations,
                maxTestCaseSize: 200
            )

            var oneOrMoreDidSomething = false

            property("State matches local reference after random operations", arguments: args) <-
                forAll { (ops: [RelationshipOp]) in
                    let owners = [String](repeating: "", count: Self.modelAmount).map {
                        Owner(name: $0)
                    }
                    let targets = [String](repeating: "", count: Self.modelAmount).map {
                        Target(name: $0)
                    }

                    let appID = "de.amethystsoft.vein.tests.RandomOneToMany"

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

                    oneOrMoreDidSomething = targets.contains {
                        !$0.owner.isNil
                    } || oneOrMoreDidSomething

                    // Verification using a fresh context to ensure changes are read from db
                    let verificationContainer = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        connection: container.getConnection(),
                        appID: appID,
                        encryptionEnabled: false
                    )
                    
                    let ownerResult = try verificationContainer.context.checkRelationshipIntegrity(of: Owner.self)
                    let targetResult = try verificationContainer.context.checkRelationshipIntegrity(of: Target.self)

                    return try (
                        State.matches(verificationContainer, oldContainer: container)
                        && ownerResult.didPass
                        && targetResult.didPass
                        ) <?> "diverged after save"
                }
            XCTAssertTrue(oneOrMoreDidSomething)
        }
    }

    fileprivate enum RelationshipOp: CustomStringConvertible {
        // Add and reparent are effectively the same thing
        case add(target: Int, to: Int, amount: Int)

        case removeOne(target: Int, from: Int)

        case removeEverything(from: Int)

        case removeAll(target: Int, from: Int)

        case setOwnerNil(Int)

        case setOwner(Int, to: Int)

        var description: String {
            switch self {
                case .add(let target, let to, let amount):
                    return "add(target: \(target), to: \(to), amount: \(amount))"
                case .removeOne(let target, let from):
                    return "removeOne(target: \(target), from: \(from))"
                case .removeEverything(let from):
                    return "removeEverything(from: \(from))"
                case .removeAll(let target, let from):
                    return "removeAll(target: \(target), from: \(from))"
                case .setOwnerNil(let target):
                    return "setOwnerNil(\(target))"
                case .setOwner(let owner, let target):
                    return "setOwner(\(owner), \(target))"
            }
        }
    }

    extension RelationshipOp {
        fileprivate func perform(
            on container: ModelContainer,
            owners: [Owner],
            targets: [Target]
        ) throws {
            switch self {
                case .add(let targetIndex, let ownerIndex, let amount):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]
                    owner.targets.append(contentsOf: Array(repeating: target, count: amount))
                case .removeOne(let targetIndex, let ownerIndex):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]

                    if let index = owner.targets.firstIndex(where: { $0 === target }) {
                        owner.targets.remove(at: index)
                    }
                case .removeEverything(let ownerIndex):
                    let owner = owners[ownerIndex]

                    owner.targets = []
                case .removeAll(let targetIndex, let ownerIndex):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]

                    owner.targets.removeAll {
                        $0 === target
                    }
                case .setOwnerNil(let targetIndex):
                    let target = targets[targetIndex]
                    target.owner = nil
                case .setOwner(let ownerIndex, let targetIndex):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]
                    target.owner = owner
            }
        }
    }

    extension RelationshipOp: Arbitrary {
        fileprivate static var arbitrary: Gen<RelationshipOp> {
            let index = Gen<Int>.sized { size in
                Gen<Int>.choose((0, SwiftCheckOneToManyRelationshipSuite.modelAmount - 1))
            }

            let opChoice = Gen<Int>.frequency([
                (6, Gen<Int>.choose((0, 0))),
                (3, Gen<Int>.choose((1, 1))),
                (1, Gen<Int>.choose((2, 2))),
                (1, Gen<Int>.choose((3, 3))),
                (1, Gen<Int>.choose((4, 4))),
                (3, Gen<Int>.choose((5, 5)))
            ])

            return Gen<RelationshipOp>.compose { gen in
                return switch gen.generate(using: opChoice) {
                    case 0: .add(
                            target: gen.generate(using: index),
                            to: gen.generate(using: index),
                            amount: gen.generate(using: Gen<Int>.choose((1, 3)))
                        )
                    case 1: .removeOne(
                            target: gen.generate(using: index),
                            from: gen.generate(using: index)
                        )
                    case 2: .removeEverything(
                            from: gen.generate(using: index)
                        )
                    case 3: .removeAll(
                            target: gen.generate(using: index),
                            from: gen.generate(using: index)
                        )
                    case 4: .setOwnerNil(gen.generate(using: index))
                    default: .setOwner(
                            gen.generate(using: index),
                            to: gen.generate(using: index)
                        )
                }
            }
        }
    }

    fileprivate struct State {
        /// Reads everything back from the container and compares relationships to their inverse.
        static func matches(
            _ container: ModelContainer,
            oldContainer: ModelContainer? = nil
        ) throws -> Bool {
            let realOwners = try container.context.fetchAll(V0_0_1.Owner.self)
            let realTargets = try container.context.fetchAll(V0_0_1.Target.self)

            for owner in realOwners {
                for target in owner.targets {
                    if target.owner !== owner { return false }
                }
            }

            for target in realTargets {
                if
                    let owner = target.owner,
                    !owner.targets.contains(where: { $0 === target })
                { return false }
            }

            // Skip this half if oldContainer wasn't provided
            guard let oldContainer else { return true }

            let inMemoryOwners = try oldContainer.context.fetchAll(V0_0_1.Owner.self)
            let inMemoryTargets = try oldContainer.context.fetchAll(V0_0_1.Target.self)

            guard realOwners.count == inMemoryOwners.count else { return false }
            guard realTargets.count == inMemoryTargets.count else { return false }

            for (index, owner) in inMemoryOwners.enumerated() {
                if realOwners[index].targets.map(\.id) != owner.targets.map(\.id) { return false }
            }

            for (index, target) in inMemoryTargets.enumerated() {
                if realTargets[index].owner?.id != target.owner?.id { return false }
            }

            return true
        }
    }

    fileprivate enum V0_0_1: VersionedSchema {
        static let version = ModelVersion(0, 0, 1)
        static let models: [any Vein.PersistentModel.Type] = [Owner.self, Target.self]

        @Model
        final class Owner: Identifiable {
            var name: String

            @Relationship(inverse: \Target.owner)
            var targets: [Target]

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

    fileprivate enum Migration: SchemaMigrationPlan {
        static var schemas: [any Vein.VersionedSchema.Type] {
            [V0_0_1.self]
        }

        static var stages: [MigrationStage] {
            []
        }
    }

#endif
