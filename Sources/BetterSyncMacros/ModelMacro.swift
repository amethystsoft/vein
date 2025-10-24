import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion

public struct ModelMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }
        
        let fieldVariables: [VariableDeclSyntax] = classDecl.memberBlock.members
            .compactMap { member in
                guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                    return nil
                }
                
                let hasFieldAttribute = varDecl.attributes.contains { attr in
                    if let attrSyntax = attr.as(AttributeSyntax.self),
                       let name = attrSyntax.attributeName.as(IdentifierTypeSyntax.self) {
                        return name.name.text == "LazyField"
                    }
                    return false
                }
                
                return hasFieldAttribute ? varDecl : nil
            }
        
        let fieldNames: [String] = fieldVariables.compactMap { varDecl in
            varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        }
        
        var fieldBodys = [String]()
        var fieldAccessorBodies = [String]()
        
        fieldAccessorBodies.append("self._id")
        
        for name in fieldNames {
            fieldBodys.append("self._\(name).model = self")
            fieldBodys.append("self._\(name).key = \"\(name)\"")
            fieldAccessorBodies.append("self._\(name)")
        }
        
        fieldBodys.append("self._id.model = self")
        
        let fieldSetup = fieldBodys.joined(separator: "\n        ")
        let fieldAccessorSetup = fieldAccessorBodies.joined(separator: ",\n   ")
        
        let body =
"""
    @PrimaryKey
    var id: UUID?

    init() {
        setupFields()
    }

    /// Sets required properties for @Field values.
    /// Gets generated automatically by @Model.
    private func setupFields() {
        \(fieldSetup)
    }

    func getSchema() -> String {
        return Self.schema
    }

    var context: ManagedObjectContext? = nil
    var fields: [any BetterSync.PersistedField] {
        [
            \(fieldAccessorSetup)
        ]
    }
"""
        
        return [DeclSyntax(stringLiteral: body)]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }
        
        let className = classDecl.name.text
        
        let extensionDecl = try ExtensionDeclSyntax(
            "extension \(raw: className): PersistentModel { }"
        )
        
        return [extensionDecl]
    }
}
