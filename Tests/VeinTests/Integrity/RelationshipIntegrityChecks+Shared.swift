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
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUI
#else
    @_spi(VeinTesting) @testable import VeinCore
#endif

struct RelationshipIntegrityChecks: RelationshipIntegrityCheckHelper {
    @Test
    func `corrupted primaryULID`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            owner.target = target
        } corrupt: { connection in
            let query = Table(Owner.schema)
                .where(SQLExpression<String>("id") == owner.id.ulidString)
                .update(SQLExpression<String>("id") <- "notAValidULID")
            _ = try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == Owner.schema }!
            let targetReport = reports.first { $0.schema == Target.schema }!

            #expect(targetReport.models.count == 1)
            #expect(ownerReport.models.count == 1)

            guard
                let ownerReport = ownerReport.models.first,
                let targetReport = targetReport.models.first
            else { return }

            #expect(ownerReport.idString == "notAValidULID")
            #expect(ownerReport.inverseMismatches.count == 1)
            #expect(ownerReport.localMismatches.count == 1)
            #expect(ownerReport.inverseMismatches["target"]?[target.id.ulidString] == .inverseMismatch(found: owner.id.ulidString, expected: "notAValidULID"))
            #expect(ownerReport.localMismatches["id"] == .corruptedData)

            #expect(targetReport.id == target.id)
            #expect(targetReport.localMismatches.isEmpty)
            #expect(targetReport.inverseMismatches.count == 1)
            #expect(targetReport
                .inverseMismatches["owner"]?[owner.id.ulidString] == .missingInInverse)
        }
    }

    @Test
    func `Corrupted one-relationship data`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            owner.target = target
        } corrupt: { connection in
            let query = Table(Owner.schema)
                .where(SQLExpression<String>("id") == owner.id.ulidString)
                .update(SQLExpression<String>("target") <- "notAValidULID")
            _ = try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == Owner.schema }!
            let targetReport = reports.first { $0.schema == Target.schema }!

            #expect(targetReport.models.count == 1)
            #expect(ownerReport.models.count == 1)

            guard
                let ownerReport = ownerReport.models.first,
                let targetReport = targetReport.models.first
            else { return }

            #expect(ownerReport.idString == owner.id.ulidString)
            #expect(ownerReport.inverseMismatches.isEmpty)
            #expect(ownerReport.localMismatches.count == 1)
            #expect(ownerReport.localMismatches["target"] == .corruptedData)

            #expect(targetReport.idString == target.id.ulidString)
            #expect(targetReport.inverseMismatches.count == 1)
            #expect(targetReport.localMismatches.isEmpty)
            #expect(targetReport.inverseMismatches["owner"]?[owner.id.ulidString] == .corruptedData)
        }
    }

    @Test
    func `Corrupted many-relationship data`() async throws {
        let owner = V0_0_2.Owner(name: "Mia")
        let target = V0_0_2.Target(name: "Coral")

        try check(V0_0_2.self, Migration.self) { context in
            try context.insert(owner)
            owner.targets.append(target)
        } corrupt: { connection in
            let query = Table(V0_0_2.Owner.schema)
                .where(SQLExpression<String>("id") == owner.id.ulidString)
                .update(SQLExpression<Data>("targets") <- SQLExpression<Data>(
                    "jsonb(?)",
                    ["{\"id\": 1234}"]
                ))
            _ = try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == V0_0_2.Owner.schema }!
            let targetReport = reports.first { $0.schema == V0_0_2.Target.schema }!

            #expect(targetReport.models.count == 1)
            #expect(ownerReport.models.count == 1)

            guard
                let ownerReport = ownerReport.models.first,
                let targetReport = targetReport.models.first
            else { return }

            #expect(ownerReport.idString == owner.id.ulidString)
            #expect(ownerReport.inverseMismatches.isEmpty)
            #expect(ownerReport.localMismatches.count == 1)
            #expect(ownerReport.localMismatches["targets"] == .corruptedData)

            #expect(targetReport.idString == target.id.ulidString)
            #expect(targetReport.inverseMismatches.count == 1)
            #expect(targetReport.localMismatches.isEmpty)
            #expect(targetReport.inverseMismatches["owner"]?[owner.id.ulidString] == .corruptedData)
        }
    }

    @Test func `Multiple one fields can report`() async throws {
        let owner = V0_0_3.Owner(name: "Mia")
        let target = V0_0_3.Target(name: "Coral")

        try check(V0_0_3.self, Migration.self) { context in
            try context.insert(owner)
            owner.target = target
            owner.target2 = target
        } corrupt: { connection in
            let query = Table(V0_0_3.Target.schema)
                .drop()
            _ = try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == V0_0_3.Owner.schema }!
            let targetReport = reports.first { $0.schema == V0_0_3.Target.schema }!

            #expect(targetReport.models.count == 0)
            #expect(ownerReport.models.count == 1)

            guard let ownerReport = ownerReport.models.first else { return }
            let targetID = target.id.ulidString

            #expect(ownerReport.idString == owner.id.ulidString)
            #expect(ownerReport.inverseMismatches.count == 2)
            #expect(ownerReport.inverseMismatches["target"]?[targetID] == .missingInInverse)
            #expect(ownerReport.inverseMismatches["target2"]?[targetID] == .missingInInverse)
        }
    }

    @Test
    func `Multiple many fields can report`() async throws {
        let owner = V0_0_4.Owner(name: "Mia")
        let target = V0_0_4.Target(name: "Coral")

        try check(V0_0_4.self, Migration.self) { context in
            try context.insert(owner)
            owner.targets = [target]
            owner.targets2 = [target]
        } corrupt: { connection in
            let query = Table(V0_0_4.Target.schema)
                .drop()
            _ = try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == V0_0_4.Owner.schema }!
            let targetReport = reports.first { $0.schema == V0_0_4.Target.schema }!

            #expect(targetReport.models.count == 0)
            #expect(ownerReport.models.count == 1)

            guard let ownerReport = ownerReport.models.first else { return }
            let targetID = target.id.ulidString

            #expect(ownerReport.idString == owner.id.ulidString)
            #expect(ownerReport.inverseMismatches.count == 2)
            #expect(ownerReport.inverseMismatches["targets"]?[targetID] == .missingInInverse)
            #expect(ownerReport.inverseMismatches["targets2"]?[targetID] == .missingInInverse)
        }
    }
    
    @Test
    func `generating relationship maps correctly (Owner)`() {
        let (map, information) = RelationshipMetadataTest.Owner
            ._fieldInformation
            .inverseMaps(for: RelationshipMetadataTest.Owner.self)
        
        #expect(map == [
            "targets": "owners",
            "target2": "owners2",
            "metadata": "owner"
        ])
        
        guard
            let targetsInformation = RelationshipMetadataTest.Target
                ._fieldInformation
                .first(where: { $0.key == "owners" }),
            let target2Information = RelationshipMetadataTest.Target
                ._fieldInformation
                .first(where: { $0.key == "owners2" }),
            let metadataInformation = RelationshipMetadataTest.Metadata
                ._fieldInformation
                .first(where: { $0.key == "owner" })
        else {
            Issue.record("One or more field informations were missing.")
            return
        }
        
        #expect(information == [
            "targets": targetsInformation,
            "target2": target2Information,
            "metadata": metadataInformation
        ])
    }
    
    @Test
    func `generating relationship maps correctly (Target)`() {
        let (map, information) = RelationshipMetadataTest.Target
            ._fieldInformation
            .inverseMaps(for: RelationshipMetadataTest.Target.self)
        
        #expect(map == [
            "owners": "targets",
            "owners2": "target2"
        ])
        
        guard
            let ownersInformation = RelationshipMetadataTest.Owner
                ._fieldInformation
                .first(where: { $0.key == "targets" }),
            let owners2Information = RelationshipMetadataTest.Owner
                ._fieldInformation
                .first(where: { $0.key == "target2" })
        else {
            Issue.record("One or more field informations were missing.")
            return
        }
        
        #expect(information == [
            "owners": ownersInformation,
            "owners2": owners2Information
        ])
    }
    
    @Test
    func `generating relationship maps correctly (Metadata)`() {
        let (map, information) = RelationshipMetadataTest.Metadata
            ._fieldInformation
            .inverseMaps(for: RelationshipMetadataTest.Metadata.self)
        
        #expect(map == [
            "owner": "metadata"
        ])
        
        guard
            let metadataInformation = RelationshipMetadataTest.Owner
                ._fieldInformation
                .first(where: { $0.key == "metadata" })
        else {
            Issue.record("One or more field informations were missing.")
            return
        }
        
        #expect(information == [
            "owner": metadataInformation,
        ])
    }
    
    @Test
    func `one to none catches inverseMissing`() async throws {
        let owner = RelationshipMetadataTest.Owner(name: "Mia")
        let profilePicture = RelationshipMetadataTest.ProfilePicture(description: "trollface")
        
        try check(RelationshipMetadataTest.self, Migration.self) { context in
            try context.insert(owner)
            owner.profilePicture = profilePicture
        } corrupt: { connection in
            let query = Table(RelationshipMetadataTest.ProfilePicture.schema)
                .where(SQLExpression<String>("id") == profilePicture.id.ulidString)
                .delete()
            try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == RelationshipMetadataTest.Owner.schema }!
            let profilePictureReport = reports.first { $0.schema == RelationshipMetadataTest.ProfilePicture.schema }!
            
            #expect(profilePictureReport.models.count == 0)
            #expect(ownerReport.models.count == 1)
            
            guard let ownerReport = ownerReport.models.first else { return }
            
            #expect(ownerReport.idString == owner.id.ulidString)
            #expect(ownerReport.inverseMismatches.count == 1)
            #expect(ownerReport.localMismatches.isEmpty)
            #expect(
                ownerReport.inverseMismatches["profilePicture"]?[profilePicture.id.ulidString]
                == .missingInInverse
            )
        }
    }
    
    @Test
    func `many to none catches inverseMissing`() async throws {
        let owner = RelationshipMetadataTest.Owner(name: "Mia")
        let profilePicture = RelationshipMetadataTest.ProfilePicture(description: "trollface")
        
        try check(RelationshipMetadataTest.self, Migration.self) { context in
            try context.insert(owner)
            owner.reservePictures = [profilePicture]
            print(profilePicture.isManaged)
        } corrupt: { connection in
            let query = Table(RelationshipMetadataTest.ProfilePicture.schema)
                .where(SQLExpression<String>("id") == profilePicture.id.ulidString)
                .delete()
            try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == RelationshipMetadataTest.Owner.schema }!
            let profilePictureReport = reports.first { $0.schema == RelationshipMetadataTest.ProfilePicture.schema }!
            
            #expect(profilePictureReport.models.count == 0)
            #expect(ownerReport.models.count == 1)
            
            guard let ownerReport = ownerReport.models.first else { return }
            
            #expect(ownerReport.idString == owner.id.ulidString)
            #expect(ownerReport.inverseMismatches.count == 1)
            #expect(ownerReport.localMismatches.isEmpty)
            #expect(
                ownerReport.inverseMismatches["reservePictures"]?[profilePicture.id.ulidString]
                == .missingInInverse
            )
        }
    }
}

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

fileprivate enum V0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 2)
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

fileprivate enum V0_0_3: VersionedSchema {
    static let version = ModelVersion(0, 0, 3)
    static let models: [any Vein.PersistentModel.Type] = [Owner.self, Target.self]

    @Model
    final class Owner: Identifiable {
        var name: String

        @Relationship(inverse: \Target.owner)
        var target: Target?

        @Relationship(inverse: \Target.owner2)
        var target2: Target?

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Target: Identifiable {
        var name: String

        @Relationship
        var owner: Owner?

        @Relationship
        var owner2: Owner?

        init(name: String) {
            self.name = name
        }
    }
}

fileprivate enum V0_0_4: VersionedSchema {
    static let version = ModelVersion(0, 0, 4)
    static let models: [any Vein.PersistentModel.Type] = [Owner.self, Target.self]

    @Model
    final class Owner: Identifiable {
        var name: String

        @Relationship(inverse: \Target.owners)
        var targets: [Target]

        @Relationship(inverse: \Target.owners2)
        var targets2: [Target]

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Target: Identifiable {
        var name: String

        @Relationship
        var owners: [Owner]

        @Relationship
        var owners2: [Owner]

        init(name: String) {
            self.name = name
        }
    }
}

fileprivate enum RelationshipMetadataTest: VersionedSchema {
    static let version = ModelVersion(0, 0, 5)
    static let models: [any Vein.PersistentModel.Type] = [
        Owner.self, Target.self, ProfilePicture.self, Metadata.self
    ]
    
    @Model
    final class Owner: Identifiable {
        var name: String
        
        @Relationship(inverse: \Target.owners)
        var targets: [Target]
        
        @Relationship
        var target2: Target?
        
        @Relationship
        var profilePicture: ProfilePicture?
        
        @Relationship
        var reservePictures: [ProfilePicture]
        
        @Relationship
        var metadata: Metadata?
        
        init(name: String) {
            self.name = name
        }
    }
    
    @Model
    final class Target: Identifiable {
        var name: String
        
        @Relationship
        var owners: [Owner]
        
        @Relationship(inverse: \Owner.target2)
        var owners2: [Owner]
        
        init(name: String) {
            self.name = name
        }
    }
    
    @Model
    final class ProfilePicture: Identifiable {
        var description: String
        
        @LazyField
        var data: Data?
        
        init(description: String) {
            self.description = description
        }
    }
    
    @Model
    final class Metadata: Identifiable {
        var createdAt: Date
        
        @Relationship(inverse: \Owner.metadata)
        var owner: Owner?
        
        init(createdAt: Date) {
            self.createdAt = createdAt
        }
    }
}

fileprivate typealias Owner = V0_0_1.Owner
fileprivate typealias Target = V0_0_1.Target

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self, V0_0_2.self, V0_0_3.self, V0_0_4.self, RelationshipMetadataTest.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
