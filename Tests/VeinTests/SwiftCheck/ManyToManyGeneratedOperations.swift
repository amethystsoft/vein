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

    final class SwiftCheckManyToManyRelationshipSuite: XCTestCase {
        static let modelAmount = 5
        // Scope: Test it always leaves a result that makes sense.
        func testRandomManyToManyOperations() throws {
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

                    let appID = "de.amethystsoft.vein.tests.RandomManyToMany"

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

                    // To make sure something happened
                    oneOrMoreDidSomething = owners.contains {
                        !$0.underlyingValue.isEmpty
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

                    return try (State.matches(verificationContainer, oldContainer: container)
                    && ownerResult.didPass
                    && targetResult.didPass)
                    <?> "diverged after save"
                }
            XCTAssertTrue(oneOrMoreDidSomething)
        }
    }

    fileprivate enum RelationshipOp: CustomStringConvertible {
        case addTarget(target: Int, to: Int, amount: Int)
        case addOwner(owner: Int, to: Int, amount: Int)

        case removeOneTarget(target: Int, from: Int)
        case removeOneOwner(owner: Int, from: Int)

        case removeEverythingFromOwner(from: Int)
        case removeEverythingFromTarget(from: Int)

        case removeAllTargets(target: Int, from: Int)
        case removeAllOwners(owner: Int, from: Int)

        var description: String {
            switch self {
                case .addTarget(let target, let to, let amount):
                    return "addTarget(target: \(target), to: \(to), amount: \(amount))"
                case .addOwner(let owner, let to, let amount):
                    return "addOwner(owner: \(owner), to: \(to), amount: \(amount))"
                case .removeOneTarget(let target, let from):
                    return "removeOneTarget(target: \(target), from: \(from))"
                case .removeOneOwner(let owner, let from):
                    return "removeOneOwner(owner: \(owner), from: \(from))"
                case .removeEverythingFromTarget(let from):
                    return "removeEverythingFromTarget(from: \(from))"
                case .removeEverythingFromOwner(let from):
                    return "removeEverythingFromOwner(from: \(from))"
                case .removeAllTargets(let target, let from):
                    return "removeAllTargets(target: \(target), from: \(from))"
                case .removeAllOwners(let owner, let from):
                    return "removeAllOwners(owner: \(owner), from: \(from))"
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
                case .addTarget(let targetIndex, let ownerIndex, let amount):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]
                    owner.targets.append(contentsOf: Array(repeating: target, count: amount))
                case .addOwner(let ownerIndex, let targetIndex, let amount):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]
                    target.owners.append(contentsOf: Array(repeating: owner, count: amount))
                case .removeOneTarget(let targetIndex, let ownerIndex):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]

                    if let index = owner.targets.firstIndex(where: { $0 === target }) {
                        owner.targets.remove(at: index)
                    }
                case .removeOneOwner(let ownerIndex, let targetIndex):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]

                    if let index = target.owners.firstIndex(where: { $0 === owner }) {
                        target.owners.remove(at: index)
                    }
                case .removeEverythingFromOwner(let ownerIndex):
                    let owner = owners[ownerIndex]

                    owner.targets = []
                case .removeEverythingFromTarget(let targetIndex):
                    let target = targets[targetIndex]

                    target.owners = []
                case .removeAllTargets(let targetIndex, let ownerIndex):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]

                    owner.targets.removeAll {
                        $0 === target
                    }
                case .removeAllOwners(let ownerIndex, let targetIndex):
                    let target = targets[targetIndex]
                    let owner = owners[ownerIndex]

                    target.owners.removeAll {
                        $0 === owner
                    }
            }
        }
    }

    extension RelationshipOp: Arbitrary {
        fileprivate static var arbitrary: Gen<RelationshipOp> {
            let index = Gen<Int>.sized { size in
                Gen<Int>.choose((0, SwiftCheckManyToManyRelationshipSuite.modelAmount - 1))
            }

            let opChoice = Gen<Int>.frequency([
                (6, Gen<Int>.choose((0, 0))),
                (6, Gen<Int>.choose((1, 1))),
                (3, Gen<Int>.choose((2, 2))),
                (3, Gen<Int>.choose((3, 3))),
                (1, Gen<Int>.choose((4, 4))),
                (1, Gen<Int>.choose((5, 5))),
                (1, Gen<Int>.choose((6, 6))),
                (1, Gen<Int>.choose((7, 7))),
            ])

            return Gen<RelationshipOp>.compose { gen in
                return switch gen.generate(using: opChoice) {
                    case 0: .addTarget(
                            target: gen.generate(using: index),
                            to: gen.generate(using: index),
                            amount: gen.generate(using: Gen<Int>.choose((1, 3)))
                        )
                    case 1: .addOwner(
                            owner: gen.generate(using: index),
                            to: gen.generate(using: index),
                            amount: gen.generate(using: Gen<Int>.choose((1, 3)))
                        )
                    case 2: .removeOneTarget(
                            target: gen.generate(using: index),
                            from: gen.generate(using: index)
                        )
                    case 3: .removeOneOwner(
                            owner: gen.generate(using: index),
                            from: gen.generate(using: index)
                        )
                    case 4: .removeEverythingFromOwner(
                            from: gen.generate(using: index)
                        )
                    case 5: .removeEverythingFromTarget(
                            from: gen.generate(using: index)
                        )
                    case 6: .removeAllTargets(
                            target: gen.generate(using: index),
                            from: gen.generate(using: index)
                        )
                    default:.removeAllOwners(
                            owner: gen.generate(using: index),
                            from: gen.generate(using: index)
                        )
                }
            }
        }
    }

    fileprivate struct State {
        /// Reads everything back from the container and compares the two relationship sides.
        static func matches(
            _ container: ModelContainer,
            oldContainer: ModelContainer? = nil
        ) throws -> Bool {
            let realOwners = try container.context.fetchAll(V0_0_1.Owner.self)
            let realTargets = try container.context.fetchAll(V0_0_1.Target.self)

            for owner in realOwners {
                for target in owner.targets {
                    let targetCount = owner.underlyingValue.count { $0 == target.id }
                    let ownerCount = target.underlyingValue.count { $0 == owner.id }

                    if targetCount != ownerCount { return false }
                }
            }

            for target in realTargets {
                for owner in target.owners {
                    let targetCount = owner.underlyingValue.count { $0 == target.id }
                    let ownerCount = target.underlyingValue.count { $0 == owner.id }

                    if targetCount != ownerCount { return false }
                }
            }

            // Skip this half if oldContainer wasn't provided
            guard let oldContainer else { return true }

            let inMemoryOwners = try oldContainer.context.fetchAll(V0_0_1.Owner.self)
            let inMemoryTargets = try oldContainer.context.fetchAll(V0_0_1.Target.self)

            guard realOwners.count == inMemoryOwners.count else { return false }
            guard realTargets.count == inMemoryTargets.count else { return false }

            for (index, owner) in inMemoryOwners.enumerated() {
                if realOwners[index].underlyingValue != owner.underlyingValue { return false }
            }

            for (index, target) in inMemoryTargets.enumerated() {
                if realTargets[index].underlyingValue != target.underlyingValue { return false }
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

            @Relationship(inverse: \Target.owners)
            var targets: [Target]

            init(name: String) {
                self.name = name
            }

            var underlyingValue: [ULID] {
                _targets._persistableValue
            }
        }

        @Model
        final class Target: Identifiable {
            var name: String

            @Relationship
            var owners: [Owner]

            init(name: String) {
                self.name = name
            }

            var underlyingValue: [ULID] {
                _owners._persistableValue
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
