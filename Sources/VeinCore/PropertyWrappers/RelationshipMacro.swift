import Vein

@attached(peer)
public macro Relationship(
    inverse: AnyKeyPath? = nil,
    deleteRule: DeleteRule = .nullify
) = #externalMacro(
    module: "VeinCoreMacros",
    type: "RelationshipMarkerMacro"
)
