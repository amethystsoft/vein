#if canImport(Combine)
import Combine
import Vein

@attached(member, names: named(init), named(id), named(_setupFields), named(context), named(_getSchema), named(_fields), named(_relationships), named(_fieldInformation), named(objectWillChange), named(_key), named(_PredicateHelper), named(_satisfiesConstraint), named(notifyOfChanges), named(_isPreparedForDeletion), named(_inverseFields), named(_observers))
@attached(extension, conformances: PersistentModel, Sendable, ObservableObject, names: named(version), named(schema))
@attached(peer, names: arbitrary)
@attached(memberAttribute)
public macro Model() = #externalMacro(
    module: "VeinSwiftUIMacros",
    type: "ModelMacro"
)
#endif
