import Foundation

@attached(member, names: named(init), named(id), named(setupFields), named(context))
@attached(extension, conformances: PersistentModel)
public macro Model<each P: Protocol>(_ constraints: repeat each P) = #externalMacro(
    module: "BetterSyncMacros",
    type: "ModelMacro"
)
