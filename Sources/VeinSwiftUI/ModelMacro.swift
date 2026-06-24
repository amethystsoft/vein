#if canImport(Combine)
@_exported import Combine
import Vein

@attached(member, names: named(init), named(id), named(_setupFields), named(context), named(_getSchema), named(_fields), named(_relationships), named(_fieldInformation), named(objectWillChange), named(_key), named(_satisfiesConstraint), named(notifyOfChanges), named(_isPreparedForDeletion), named(_inverseFields), named(_observers), named(_predicateInformation))
@attached(extension, conformances: PersistentModel, Sendable, ObservableObject, names: named(version), named(schema))
@attached(memberAttribute)
public macro Model() = #externalMacro(
    module: "VeinSwiftUIMacros",
    type: "ModelMacro"
)
#endif
