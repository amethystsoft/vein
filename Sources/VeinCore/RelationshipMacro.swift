import Vein

/// A marker macro used by ``Model()`` to identify relationships.
@attached(peer)
public macro Relationship(
    inverse: AnyKeyPath? = nil,
    deleteRule: DeleteRule = .nullify
) = #externalMacro(
    module: "VeinCoreMacros",
    type: "RelationshipMarkerMacro"
)
