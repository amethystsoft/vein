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
class StaleReferenceCleanup: XCTestCase {
    func testCleanup() {
        var hadULIDsRemoved = false
        let args = CheckerArguments(maxTestCaseSize: 20)
        property("State matches local reference after random operations", arguments: args) <-
        forAll { (stable: [Stable], unstable: [Unstable]) in
            if stable.count == 0 && unstable.count == 0 { return true }
            return try self.test() { context in
                for element in stable {
                    try element.create(in: context)
                }
                
                var removedULIDs: Set<String> = []
                
                for element in unstable {
                    let removed = try element.create(in: context)
                    
                    for remove in removed {
                        removedULIDs.insert(remove)
                    }
                }
                
                if !removedULIDs.isEmpty {
                    hadULIDsRemoved = true
                }
                
                return removedULIDs
            } checkCleaned: { context in
                return true
            }
        }
        
        XCTAssertTrue(hadULIDsRemoved)
    }
    
    func test(
        setup: (ManagedObjectContext) throws -> Set<String>,
        checkCleaned: (ManagedObjectContext) throws -> Bool
    ) throws -> Bool {
        let container = try ModelContainer(
            V1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.test.StaleReferenceCleanup",
            encryptionEnabled: false
        )
        
        let removed = try setup(container.context)
        try container.context.save()
        
        let newContainer = try ModelContainer(
            V1.self,
            migration: Migration.self,
            connection: container.getConnection(),
            appID: "de.amethystsoft.vein.test.StaleReferenceCleanup",
            encryptionEnabled: false
        )
        
        let precheck = try newContainer.context.checkRelationshipIntegrity()
        guard let precheckParentReport = precheck.first(where: { $0.schema == Parent.schema }) else {
            return false
        }
        for remove in removed {
            var found = false
            for model in precheckParentReport.models {
                found = model.inverseMismatches.contains { (_, value) in
                    value.contains { (id, mismatch) in
                        if case .missingInInverse = mismatch {
                            return id == remove
                        }
                        return false
                    }
                }
                if found { break }
            }
            
            if !found {
                return false
            }
        }
        
        let result = try newContainer.context.checkRelationshipIntegrity(removingStaleReferences: true)
        
        let childReport = result.first { $0.schema == Child.schema }
        if childReport?.didPass != true {
            return false
        }
        let parentReport = result.first { $0.schema == Child.schema }
        if parentReport?.didPass != true {
            return false
        }
        
        let afterCleanup = try newContainer.context.checkRelationshipIntegrity()
        let checkPassed = try checkCleaned(newContainer.context)
        
        return checkPassed && !afterCleanup.contains {
            $0.didPass == false
        }
    }
}

fileprivate enum V1: VersionedSchema {
    static let version: Vein.ModelVersion = .init(1, 0, 0)
    static let models: [any Vein.PersistentModel.Type] = [ Parent.self, Child.self ]

    @Model
    final class Parent {
        var name: String
        @Relationship(inverse: \Child.parent)
        var child: Child?
        @Relationship(inverse: \Child.parent1)
        var children: [Child]
        
        init(name: String) {
            self.name = name
        }
    }
    
    @Model
    final class Child {
        var name: String
        @Relationship
        var parent: Parent?
        @Relationship
        var parent1: Parent?
        
        init(name: String) {
            self.name = name
        }
    }
}

fileprivate typealias Parent = V1.Parent
fileprivate typealias Child = V1.Child

fileprivate enum Migration: SchemaMigrationPlan {
    static let stages: [Vein.MigrationStage] = []
    static let schemas: [any Vein.VersionedSchema.Type] = [V1.self]
}

fileprivate struct ParentDTO {
    let name: String
    let children: [String]
    let child: String?
}

fileprivate struct Stable {
    let parent: ParentDTO
}

fileprivate struct Unstable {
    let parent: ParentDTO
    let removeChildren: Set<String>
}

extension Stable: Arbitrary {
    static var arbitrary: Gen<Stable> {
        return Gen<Stable>.compose { gen in
            let parent = ParentDTO(
                name: gen.generate(),
                children: gen.generate(),
                child: gen.generate()
            )
            return Stable(parent: parent)
        }
    }
}

extension Stable {
    func create(in context: ManagedObjectContext) throws {
        let parent = Parent(name: self.parent.name)
        try context.insert(parent)
        
        var children = [Child]()
        for child in self.parent.children {
            children.append(Child(name: child))
        }
        parent.children = children
        
        if let child = self.parent.child {
            let newChild = Child(name: child)
            parent.child = newChild
        }
    }
}

extension Unstable: Arbitrary {
    static var arbitrary: Gen<Unstable> {
        return Gen<Unstable>.compose { gen in
            let addedChildren: [String] = gen.generate()
            let addedChild: String? = gen.generate()
            
            var total = addedChildren
            if let addedChild {
                total.append(addedChild)
            }
            
            let parent = ParentDTO(
                name: gen.generate(),
                children: addedChildren,
                child: addedChild
            )
            
            if total.count >= 1 {
                let stringGen = Gen<String>.fromElements(of: total)
                var toRemove = [String]()
                
                for _ in 0..<total.count {
                    let add: Bool = gen.generate()
                    if add {
                        toRemove.append(gen.generate(using: stringGen))
                    }
                }
                
                return Unstable(parent: parent, removeChildren: Set(toRemove))
            }
            
            return Unstable(parent: parent, removeChildren: [])
        }
    }
}

extension Unstable {
    func create(in context: ManagedObjectContext) throws -> [String] {
        let stable = Stable(parent: self.parent)
        try stable.create(in: context)
        
        try context.save()
        
        let connection = context.connection
        return try connection.removeWhereNameMatches(
            names: Array(self.removeChildren),
            schema: Child.schema
        )
    }
}
#endif
