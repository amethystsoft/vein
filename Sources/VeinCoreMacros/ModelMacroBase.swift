import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation

public struct ModelMacroBase {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf classDecl: SwiftSyntax.ClassDeclSyntax,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
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
        
        let eagerVarInit = eagerFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "self.\(key) = try! \(value).init(fromPersistent: \(value).PersistentRepresentation.decode(sqliteValue: fields[\"\(key)\"]!))!"
        }.joined(separator: "\n        ")
        
        var fieldInformation = lazyFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", false)"
        }
        fieldInformation.append(contentsOf: eagerFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", true)"
        })
        
        let fieldInformationString = fieldInformation.joined(separator: ",\n        ")
        
        let body =
"""
    typealias _PredicateHelper = _\(className)PredicateHelper

    @PrimaryKey
    var id: ULID
    
    required init(id: ULID, fields: [String: Vein.SQLiteValue]) {
        self.id = id
        \(eagerVarInit)
        _setupFields()
    }

    /// Sets required properties for @Field values.
    /// Gets generated automatically by @Model.
    public func _setupFields() {
        \(fieldSetup)
    }

    var context: Vein.ManagedObjectContext? = nil
    var _fields: [any Vein.PersistedField] {
        [
            \(fieldAccessorSetup)
        ]
    }

    static let _fieldInformation: [Vein.FieldInformation] = [
        \(fieldInformationString)
    ]
"""
        
        return [DeclSyntax(stringLiteral: body)]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo classDecl: ClassDeclSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(raw: type): Vein.PersistentModel, @unchecked Sendable { 
                static let schema = "\(raw: type)"
                static var version: Vein.ModelVersion { \("\("\(type)".prefix(while: { $0 != "."})).version") }
            }
            """
        )
        
        return [extensionDecl]
    }
    
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf classDecl: ClassDeclSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        let className = classDecl.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let persistedFields: [VariableDeclSyntax] = classDecl.memberBlock.members
            .compactMap { member in
                guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                    return nil
                }
                
                let hasFieldAttribute = varDecl.attributes.contains { attr in
                    if let attrSyntax = attr.as(AttributeSyntax.self),
                       let name = attrSyntax.attributeName.as(IdentifierTypeSyntax.self) {
                        return name.name.text == "LazyField"  ||
                        name.name.text == "Field"
                    }
                    return false
                }
                
                return hasFieldAttribute ? varDecl : nil
            }
        
        var fieldNamesAndTypes = [String: String]()
        for varDecl in persistedFields {
            guard let binding = varDecl.bindings.first else { continue }
            guard
                let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                let datatype = binding.typeAnnotation?.description
            else { continue }
            fieldNamesAndTypes[name] = datatype.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        fieldNamesAndTypes["id"] = "ULID"
        
        let methods = fieldNamesAndTypes.map { (name, type) in
            """
            func \(name)(_ op: Vein.ComparisonOperator, _ value: \(type)) -> Self {
                var copy = self
                copy.builder = builder.addCheck(op, \"\(name)\", value)
                return copy
            }
            
            static func \(name)(_ op: Vein.ComparisonOperator, _ value: \(type)) -> Self {
                var copy = Self()
                copy.builder = copy.builder.addCheck(op, \"\(name)\", value)
                return copy
            }
            """
        }.joined(separator: "\n    ")
        
        let predicateBuilder = """
        struct _\(className)PredicateHelper: Vein.PredicateConstructor {
            typealias Model = \(className)
            private var builder: Vein.PredicateBuilder<\(className)>
            
            init() {
                self.builder = Vein.PredicateBuilder<\(className)>()
            }
            
            \(methods)
        
            func _builder() -> Vein.PredicateBuilder<\(className)> {
                return builder
            }
        }
        """
        
        return [DeclSyntax(stringLiteral: predicateBuilder)]
    }
}
public struct DebugDiag: DiagnosticMessage {
    public let message: String
    public var diagnosticID: MessageID { .init(domain: "VeinMacros", id: "debug") }
    public var severity: DiagnosticSeverity { .warning }
}

