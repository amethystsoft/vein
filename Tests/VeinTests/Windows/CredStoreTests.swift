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

#if canImport(WinSDK)
    @testable import Vein
    import Testing

    @Suite
    struct WinCredentialTest {
        @Test
        func ensureEncodeDecode() async throws {
            let ressource = "de.amethystsoft.vein.WinCredentialTest"
            let username = "VeinCredentialTest"
            let secret = "test123-"

            WinCredential.store(
                ressource: ressource,
                username: username,
                secret: secret
            )

            let result = WinCredential.retrieve(ressource: ressource)

            #expect(secret == result)
        }
    }
#endif
