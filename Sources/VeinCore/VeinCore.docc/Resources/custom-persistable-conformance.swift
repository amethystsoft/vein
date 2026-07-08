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

extension Date: Persistable {
    public typealias PersistentRepresentation = Double

    public var asPersistentRepresentation: Double { self.timeIntervalSince1970 }

    public init?(fromPersistent representation: PersistentRepresentation) {
        self = Date(timeIntervalSince1970: representation)
    }
}
