import Combine
import BetterSync

@attached(member, names: named(init), named(id), named(setupFields), named(context), named(_getSchema), named(_fields), named(_fieldInformation), named(objectWillChange), named(_key), named(_PredicateHelper), named(_satisfiesConstraint))
@attached(extension, conformances: PersistentModel, Sendable, ObservableObject)
@attached(peer, names: arbitrary)
public macro Model() = #externalMacro(
    module: "BetterSyncMacros",
    type: "ModelMacro"
)
