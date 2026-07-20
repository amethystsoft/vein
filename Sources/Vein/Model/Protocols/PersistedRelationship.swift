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

import ULID

///  This is mostly an implementation detail, currently making your own relationships is not supported.
public protocol PersistedRelationship: FieldBase, AnyObject {
    associatedtype Value
    var wrappedValue: Value { get set }
    func _handleModelDeletion()
    var wasTouched: Bool { get set }
}

/// This is mostly an implementation detail, currently making your own relationships is not supported.
public protocol ManyRelationship: PersistedRelationship {
    var _persistableValue: [ULID] { get set }
}
/// This is mostly an implementation detail, currently making your own relationships is not supported.
public protocol OneRelationship: PersistedRelationship {
    var _persistableValue: ULID? { get set }
}

/// Constants that define the cleanup behavior for related objects when a parent object is deleted.
public enum DeleteRule {
    /// The reference to the deleted object is set to `nil` or removed from the array.
    ///
    /// Use this rule when the child object should persist even if the relationship is severed.
    case nullify
    /// The related objects are automatically deleted along with the parent object.
    ///
    /// Use this rule for dependent relationships where the child object cannot or
    /// should not exist without its parent.
    case cascade
}
