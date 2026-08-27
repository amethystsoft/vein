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

/// A structure for configuring Vein's runtime behavior.
public struct ModelConfiguration: Sendable {
    /// Whether to clean up stale identity map entries on ``ManagedObjectContext/save()``.
    public var cleanStaleIdentityMapEntriesOnSave: Bool = true

    /// Whether to schedule cleans on the context actor and with which timeout.
    ///
    /// Disabled via `nil` by default.
    public var cleanStaleIdentityMapEntriesTimeoutSeconds: UInt16? = nil

    /// Creates a default ``ModelConfiguration``
    public init() {}

    public static var `default`: Self { .init() }
}
