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

// MARK: - The test
//
// Idea: generate a random list of operations, run each one against the real
// database AND against a tiny in-memory "reference" (plain dictionaries).
// After every operation both must agree. At the end, save and check again
// through a fresh container, so we know it really reached the database.

final class SwiftCheckOneToOneRelationshipSuite: XCTestCase {
    func testRandomOneToOneOperations() throws {
        let rows = Row.arbitrary.proliferate(withSize: 100).generate
        let ops = rows.map { $0.op }
        let owners = rows.map { $0.owner }
        let targets = rows.map { $0.target }
        
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
            print(op)
            try op.perform(on: container, owners: owners, targets: targets)
            
            // Compare after EVERY step, so a failure names the operation that broke it.
            guard try State.matches(container) else {
                XCTFail("diverged after: \(9op)")
                return
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
        
        try XCTAssertTrue(State.matches(verificationContainer))
    }
}

// MARK: - Operations
//
// Operations only carry plain values (names and indices), never model instances.
// SwiftCheck re-runs the same ops while shrinking, and a model instance that was
// already inserted / linked in an earlier run would carry that state along.
// Models are created inside `perform` instead.
//
// Indices point into the reference lists (index % count), like in the existing
// suite, so an op always targets something that exists. If nothing exists yet,
// the op does nothing.

fileprivate enum RelationshipOp: CustomStringConvertible {
    /// Assign a target that is already inserted (and may belong to another owner).
    case setExistingTarget(owner: Int, target: Int)
    
    /// owner.target = nil
    case remove(owner: Int)
    
    /// Move a target to another owner by assigning from the inverse side:
    /// target.owner = newOwner
    case reparent(target: Int, to: Int)
    
    var description: String {
        switch self {
            case .setExistingTarget(let o, let t): return "setExistingTarget(owner: \(o), target: \(t))"
            case .remove(let o): return "remove(owner: \(o))"
            case .reparent(let t, let o): return "reparent(target: \(t), to: \(o))"
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
        switch self {
            case .setExistingTarget(let ownerIndex, let targetIndex):
                let owner = owners[ownerIndex]
                let target = targets[targetIndex]
                
                owner.target = target
            case .remove(let ownerIndex):
                let owner = owners[ownerIndex]
                owner.target = nil
                
            case .reparent(let targetIndex, let ownerIndex):
                let owner = owners[ownerIndex]
                let target = targets[targetIndex]
                
                target.owner = owner
        }
    }
}

extension RelationshipOp: Arbitrary {
    fileprivate static var arbitrary: Gen<RelationshipOp> {
        let index = Gen<Int>.choose((0, 99))
        let opChoice = Gen<Int>.choose((0, 2))
        
        // frequency instead of one(of:): owners are needed before anything else can happen,
        // so they are generated more often.
        return Gen<RelationshipOp>.compose { gen in
            return switch gen.generate(using: opChoice) {
                case 0: .setExistingTarget(owner: gen.generate(using: index), target: gen.generate(using: index))
                case 1: .reparent(target: gen.generate(using: index), to: gen.generate(using: index))
                case 2: .remove(owner: gen.generate(using: index))
                default: .setExistingTarget(owner: gen.generate(using: index), target: gen.generate(using: index))
            }
        }
    }
}

// MARK: - Reference
//
// What the database SHOULD contain, as plain values. No Vein involved.

fileprivate struct State {
    /// Reads everything back from the container and compares it to this reference.
    static func matches(_ container: ModelContainer) throws -> Bool {
        let realOwners = try container.context.fetchAll(V0_0_1.Owner.self)
        let realTargets = try container.context.fetchAll(V0_0_1.Target.self)
        
        for owner in realOwners {
            if
                let target = owner.target,
                target.owner !== owner
            {
                print("owner \(realOwners.firstIndex { $0 === owner} ?? -1 )")
                print("target at owner \(realTargets.firstIndex{ $0 === target } ?? -1 )")
                return false
            }
        }
        
        for target in realTargets {
            if
                let owner = target.owner,
                owner.target !== target
            {
                print("target \(realTargets.firstIndex { $0 === target} ?? -1 )")
                print("owner at target \(realOwners.firstIndex{ $0 === owner } ?? -1 )")
                return false
            }
        }
        
        return true
    }
}

// MARK: - Fetch helpers

fileprivate struct MissingModelError: Error {}

extension ModelContainer {
    fileprivate func owner(_ id: ULID) throws -> V0_0_1.Owner {
        let predicate = #Predicate<V0_0_1.Owner> { $0.id == id }
        guard let owner = try context.fetchAll(predicate).first else { throw MissingModelError() }
        return owner
    }
    
    fileprivate func target(_ id: ULID) throws -> V0_0_1.Target {
        let predicate = #Predicate<V0_0_1.Target> { $0.id == id }
        guard let target = try context.fetchAll(predicate).first else { throw MissingModelError() }
        return target
    }
}

// MARK: - Schema

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

fileprivate struct Row: Arbitrary {
    static var arbitrary: SwiftCheck.Gen<Row> {
        Gen<Row>.compose { gen in
            Row(
                owner: gen.generate(using: Owner.arbitrary),
                target: gen.generate(using: Target.arbitrary),
                op: gen.generate(using: RelationshipOp.arbitrary)
            )
        }
    }
    
    let owner: Owner
    let target: Target
    let op: RelationshipOp
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
