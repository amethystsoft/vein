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
    import WinSDK
    import Foundation

    enum WinCredential {
        static func store(resource: String, username: String, secret: String) -> Bool {
            var resourceW = Array(resource.utf16) + [0]
            var usernameW = Array(username.utf16) + [0]

            let secretData = secret.data(using: .utf16LittleEndian)!
            let secretCount = DWORD(secretData.count)

            var credential = CREDENTIALW()
            credential.Type = DWORD(CRED_TYPE_GENERIC)
            credential.Persist = DWORD(CRED_PERSIST_LOCAL_MACHINE)

            return resourceW.withUnsafeMutableBufferPointer { resBuffer in
                usernameW.withUnsafeMutableBufferPointer { userBuffer in
                    secretData.withUnsafeBytes { secretBuffer in

                        credential.TargetName = resBuffer.baseAddress
                        credential.UserName = userBuffer.baseAddress
                        credential.CredentialBlobSize = secretCount

                        let rawBlob = secretBuffer.bindMemory(to: BYTE.self).baseAddress
                        credential.CredentialBlob = UnsafeMutablePointer<BYTE>(mutating: rawBlob)

                        return CredWriteW(&credential, 0)
                    }
                }
            }
        }

        static func retrieve(resource: String) -> String? {
            var resourceW = Array(resource.utf16) + [0]
            var credentialPointer: PCREDENTIALW? = nil

            let success = resourceW.withUnsafeMutableBufferPointer { resBuffer in
                CredReadW(resBuffer.baseAddress, DWORD(CRED_TYPE_GENERIC), 0, &credentialPointer)
            }

            guard success, let cred = credentialPointer?.pointee else {
                return nil
            }

            defer { CredFree(credentialPointer) }

            let blobSize = Int(cred.CredentialBlobSize)
            guard let blob = cred.CredentialBlob else { return nil }

            let blobBuffer = UnsafeBufferPointer(start: blob, count: blobSize)
            let secretData = Data(buffer: blobBuffer)
            return String(data: secretData, encoding: .utf16LittleEndian)
        }
    }
#endif
