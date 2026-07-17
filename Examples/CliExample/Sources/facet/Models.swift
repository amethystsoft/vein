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

import VeinCore

typealias Facet = V1_0_0.Facet

enum V1_0_0: VersionedSchema {
    static let version = ModelVersion(1, 0, 0)

    static let models: [any PersistentModel.Type] = [
        Facet.self
    ]

    @Model
    final class Facet {
        var short: String
        var name: String
        var regex: String
        var replacement: String

        init(short: String, name: String, regex: String, replacement: String) {
            self.short = short
            self.name = name
            self.regex = regex
            self.replacement = replacement
        }
    }
}

enum Migration: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        V1_0_0.self
    ]
    static let stages: [MigrationStage] = []
}
