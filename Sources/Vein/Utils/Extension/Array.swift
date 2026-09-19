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

extension Array where Element: PersistentModel {
    var asIDDictionary: [ULID: Element] {
        var dictionary = [ULID: Element]()

        for element in self {
            dictionary[element.id] = element
        }

        return dictionary
    }
}
