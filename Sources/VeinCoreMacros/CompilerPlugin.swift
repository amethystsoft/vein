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

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct VeinMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        ModelMacro.self,
        RelationshipMarkerMacro.self
    ]
}
