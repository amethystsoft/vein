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

import Vein

/// A marker macro used by ``Model()`` to identify relationships.
@attached(peer)
public macro Relationship(
    inverse: AnyKeyPath? = nil,
    deleteRule: DeleteRule = .nullify
) = #externalMacro(
    module: "VeinSwiftUIMacros",
    type: "RelationshipMarkerMacro"
)
