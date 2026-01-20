import Vein

@attached(member, names: named(init), named(id), named(_setupFields), named(context), named(_getSchema), named(_fields), named(_fieldInformation), named(objectWillChange), named(_key), named(_PredicateHelper), named(_satisfiesConstraint), named(notifyOfChanges))
@attached(extension, conformances: PersistentModel, Sendable, names: named(version), named(schema))
@attached(peer, names: arbitrary)
public macro Model() = #externalMacro(
    module: "VeinCoreMacros",
    type: "ModelMacro"
)
