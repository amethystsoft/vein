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

public protocol DatabaseKeyProvider {
    static func getKey(
        fileName: String,
        service: String,
        generate: (() -> String)?
    ) throws(KeyProviderError) -> String
}

public enum KeyProviderError: Error {
    case noSuchKey
    case providerError(String)
}
