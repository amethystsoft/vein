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
import VeinCore

func tryRelationships(context: ManagedObjectContext) throws {
    let post = Post(
        title: "How to use Vein relationships?",
        content: "Again, it's pretty easy."
    )
    let attachment = Attachment(
        name: "ExampleFile",
        fileType: .swift,
        data: Data([UInt8](repeating: 0, count: 1024 * 1024)) // very real swift file
    )

    // Relationships only work with context.
    try context.insert(post)
    // Added models get inserted automatically.
    post.attachments.append(attachment)
}
