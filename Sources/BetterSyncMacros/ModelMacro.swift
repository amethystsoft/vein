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
        
        let className = classDecl.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
    var id: Int64?
    
    let objectWillChange = PassthroughSubject<Void, Never>()
    
    required init(id: Int64, fields: [String: BetterSync.SQLiteValue]) {
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
        
        #if canImport(SwiftUI)
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(raw: type): PersistentModel, @unchecked Sendable { }
            @MainActor
            extension \(raw: type): ObservableObject { }
            """
        )
        #else
        let extensionDecl = try ExtensionDeclSyntax(
            "extension \(raw: type): PersistentModel, @unchecked Sendable { }"
        )
        #endif
        
        return [extensionDecl]
    }
}
struct DebugDiag: DiagnosticMessage {
    let message: String
    var diagnosticID: MessageID { .init(domain: "BetterSyncMacros", id: "debug") }
    var severity: DiagnosticSeverity { .warning }
}
