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

#if canImport(Combine)
    @_exported import Combine
    import Vein

    /// The macro generating everything you need for your model to work with Vein.
    @attached(
        member,
        names: named(init),
        named(id),
        named(_setupFields),
        named(_context),
        named(_getSchema),
        named(_fields),
        named(_relationships),
        named(_fieldInformation),
        named(objectWillChange),
        named(_key),
        named(_satisfiesConstraint),
        named(notifyOfChanges),
        named(_isPreparedForDeletion),
        named(_inverseFields),
        named(_observers),
        named(_predicateInformation),
        named(_updatedAt),
        named(_clientID),
        named(_isDeleted)
    )
    @attached(
        extension,
        conformances: PersistentModel,
        Sendable,
        ObservableObject,
        names: named(version),
        named(schema)
    )
    @attached(memberAttribute)
    public macro Model() = #externalMacro(
        module: "VeinSwiftUIMacros",
        type: "ModelMacro"
    )
#endif
