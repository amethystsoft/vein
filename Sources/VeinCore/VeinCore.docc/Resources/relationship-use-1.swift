// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
// Licensed under Mozilla Public License v2.0
//
// See LICENSE.txt for license information
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
}
