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

import VeinCore

extension Date: Persistable {
    public typealias PersistentRepresentation = Double

    public var asPersistentRepresentation: Double { self.timeIntervalSince1970 }

    public init?(fromPersistent representation: PersistentRepresentation) {
        self = Date(timeIntervalSince1970: representation)
    }
}
