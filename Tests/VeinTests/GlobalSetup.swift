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
#if os(Linux)
    let globalInit: Void = {
        Keyring.appIdentifier.withLock { identifier in
            identifier = "de.amethystsoft.vein.tests"
        }
    }()
#endif
