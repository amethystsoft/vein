import Foundation

@attached(member, names: named(init), named(id), named(setupFields), named(context), named(getSchema), named(fields), named(fieldInformation))
@attached(extension, conformances: PersistentModel, Sendable, Identifiable)
public macro Model(namespace: String? = nil) = #externalMacro(
    module: "BetterSyncMacros",
    type: "ModelMacro"
)
