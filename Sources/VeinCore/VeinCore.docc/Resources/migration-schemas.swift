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

import VeinCore

// Our baseline schema
enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any PersistentModel.Type] = [
        Post.self,
        Attachment.self,
        Unused.self
    ]

    @Model final class Post { var title: String /* ... */ }
    @Model final class Attachment { var name: String /* ... */ }
    @Model final class Unused { var content: String /* ... */ }
}

// Our destination schema
enum V0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 2)
    static let models: [any PersistentModel.Type] = [
        Post.self,
        Attachment.self
    ]

    @Model final class Post { var title: String }

    @Model final class Attachment {
        var name: String

        // New optional field allows safe column additions
        var rating: Int?
    }
}
