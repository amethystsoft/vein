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

extension [PersistedField] {
    var eagerLoaded: [any PersistedField] {
        self.compactMap {
            if $0.isLazy { return nil }
            return $0
        }
    }
}
