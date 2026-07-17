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

import Vein

/// A marker macro used by ``Model()`` to identify relationships.
@attached(peer)
public macro Relationship(
    inverse: AnyKeyPath? = nil,
    deleteRule: DeleteRule = .nullify
) = #externalMacro(
    module: "VeinCoreMacros",
    type: "RelationshipMarkerMacro"
)
