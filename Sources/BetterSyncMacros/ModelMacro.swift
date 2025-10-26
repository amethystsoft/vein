import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation

public struct ModelMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }
        
        let lazyFieldVariables: [VariableDeclSyntax] = classDecl.memberBlock.members
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
        let fieldVariables: [VariableDeclSyntax] = classDecl.memberBlock.members
            .compactMap { member in
                guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                    return nil
                }
                
                let hasFieldAttribute = varDecl.attributes.contains { attr in
                    if let attrSyntax = attr.as(AttributeSyntax.self),
                       let name = attrSyntax.attributeName.as(IdentifierTypeSyntax.self) {
                        return name.name.text == "Field"
                    }
                    return false
                }
                
                return hasFieldAttribute ? varDecl : nil
            }
        
        var eagerFields = [String: String]()
        for varDecl in fieldVariables {
            guard let binding = varDecl.bindings.first else { continue }
            guard
                let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                let datatype = binding.typeAnnotation?.description
            else { continue }
            eagerFields[name] = datatype
        }
        
        var lazyFields = [String: String]()
        for varDecl in lazyFieldVariables {
            guard let binding = varDecl.bindings.first else { continue }
            guard
                let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                let datatype = binding.typeAnnotation?.description
            else { continue }
            lazyFields[name] = datatype
        }
        
        var allFieldNames = Array(eagerFields.keys)
        allFieldNames.append(contentsOf: lazyFields.keys)
        
        var fieldBodys = [String]()
        var fieldAccessorBodies = [String]()
        
        fieldAccessorBodies.append("self._id")
        
        for name in allFieldNames {
            fieldBodys.append("self._\(name).model = self")
            fieldBodys.append("self._\(name).key = \"\(name)\"")
            fieldAccessorBodies.append("self._\(name)")
        }
        
        fieldBodys.append("self._id.model = self")
        
        let fieldSetup = fieldBodys.joined(separator: "\n        ")
        let fieldAccessorSetup = fieldAccessorBodies.joined(separator: ",\n   ")
        
        var eagerVarInit = eagerFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "self.\(key) = try! \(value).decode(sqliteValue: fields[\"\(key)\"]!)"
        }.joined(separator: "\n        ")
        
        var fieldInformation = lazyFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "BetterSync.FieldInformation(\(value).sqliteTypeName, \"\(key)\", false)"
        }
        fieldInformation.append(contentsOf: eagerFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "BetterSync.FieldInformation(\(value).sqliteTypeName, \"\(key)\", true)"
        })
        
        let fieldInformationString = fieldInformation.joined(separator: ",\n        ")
        
        let body =
"""
    @PrimaryKey
    var id: UUID?

    required init(id: UUID, fields: [String: BetterSync.SqliteValue]) {
        self.id = id
        \(eagerVarInit)
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

    var context: BetterSync.ManagedObjectContext? = nil
    var fields: [any BetterSync.PersistedField] {
        [
            \(fieldAccessorSetup)
        ]
    }

    static var fieldInformation: [FieldInformation] = [
        \(fieldInformationString)
    ]
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
        
        var namespace: String?
        
        /*let arg = node.as(MacroExpansionExprSyntax.self)?.arguments.first?.expression
        let literalValue = arg?.as(StringLiteralExprSyntax.self)?.representedLiteralValue
        
        namespace = literalValue*/
        
        namespace?.append(".")
        
        let extensionDecl = try ExtensionDeclSyntax(
            "extension \(raw: namespace ?? "")\(raw: className): PersistentModel, @unchecked Sendable { }"
        )
        
        return [extensionDecl]
    }
}
struct DebugDiag: DiagnosticMessage {
    let message: String
    var diagnosticID: MessageID { .init(domain: "BetterSyncMacros", id: "debug") }
    var severity: DiagnosticSeverity { .warning }
}
