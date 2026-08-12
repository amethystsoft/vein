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

#if canImport(AppKit) || canImport(UIKit)
    import KeychainAccess

    public typealias IntegratedKeyProvider = KeychainKeyProvider
    public struct KeychainKeyProvider: DatabaseKeyProvider {
        public static func getKey(
            fileName: String,
            service: String,
            generate: (() -> String)?
        ) throws(KeyProviderError) -> String {
            let keychain = Keychain(service: service)

            if let key = keychain[fileName] {
                return key
            } else if let generate {
                let key = generate()

                do {
                    try keychain.set(key, key: fileName)
                } catch {
                    throw .providerError(error.localizedDescription)
                }
                return key
            }

            throw .noSuchKey
        }
    }
#elseif os(Linux)
    @_exported import KeyringAccess

    public typealias IntegratedKeyProvider = KeyringKeyProvider
    public struct KeyringKeyProvider: DatabaseKeyProvider {
        public static func getKey(
            fileName: String,
            service: String,
            generate: (() -> String)?
        ) throws(KeyProviderError) -> String {
            let keyring = Keyring(service: service)

            if let key = keyring[fileName] {
                return key
            } else if let generate {
                let key = generate()

                do {
                    try keyring.set(key, for: fileName)
                } catch {
                    throw .providerError(error.localizedDescription)
                }
                return key
            }

            throw .noSuchKey
        }
    }
#elseif canImport(WinSDK)
    public typealias IntegratedKeyProvider = WinCredentialKeyProvider
    public struct WinCredentialKeyProvider: DatabaseKeyProvider {
        public static func getKey(
            fileName: String,
            service: String,
            generate: (() -> String)?
        ) throws(KeyProviderError) -> String {
            let ressource = "\(service)+\(fileName)"

            if let key = WinCredential.retrieve(ressource: ressource) {
                return key
            } else if let generate {
                let key = generate()

                guard WinCredential.store(
                    ressource: ressource,
                    username: "veindbsecret",
                    secret: key
                ) else {
                    throw .providerError("Failed to store key.")
                }
                return key
            }

            throw .noSuchKey
        }
    }
#endif
