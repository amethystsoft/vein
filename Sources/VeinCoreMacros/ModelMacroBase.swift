import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation

public struct ModelMacroBase {
    let frameworkName: String
    public func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf classDecl: SwiftSyntax.ClassDeclSyntax,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        let className = classDecl.name.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let lazyFieldVariables: [VariableDeclSyntax] = classDecl
            .memberBlock
            .membersWithFieldType(.lazyField, frameworkName: frameworkName)
        let fieldVariables: [VariableDeclSyntax] = classDecl
            .memberBlock
            .membersWithFieldType(.field, frameworkName: frameworkName)
        let relationshipVariables: [VariableDeclSyntax] = classDecl
            .memberBlock
            .membersWithFieldType(.relationship, frameworkName: frameworkName)
        
        let relationshipFields = relationshipVariables.fields()
        let lazyFields = lazyFieldVariables.fields()
        let eagerFields = fieldVariables.fields()
        
        // MARK: - Setup Fields & _fields accessor
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
        
        let fieldSetup = fieldBodys.joined(separator: "\n    ")
        let fieldAccessorSetup = fieldAccessorBodies.joined(separator: ",\n        ")
        
        // MARK: - Field information
        var fieldInformation = lazyFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", false)"
        }
        fieldInformation.append(contentsOf: eagerFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", true)"
        })
        
        let fieldInformationString = fieldInformation.joined(separator: ",\n    ")
        
        // MARK: - inits and assembly
        let eagerVarInit = eagerFields.initEagerRows()
        
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

var _relationships: [any PersistedRelationship] {[]}

static let _fieldInformation: [Vein.FieldInformation] = [
    \(fieldInformationString)
]
"""
        
        return [DeclSyntax(stringLiteral: body)]
    }
    
    public func expansion(
        of node: AttributeSyntax,
        attachedTo classDecl: ClassDeclSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let modelVersionString = "\("\(type)".prefix(while: { $0 != "."})).version"
        let extensionDecl = try ExtensionDeclSyntax(
            """
            extension \(raw: type): Vein.PersistentModel, @unchecked Sendable { 
                static let schema = "\(raw: type)"
                static var version: Vein.ModelVersion { \(raw: modelVersionString) }
            }
            """
        )
        
        return [extensionDecl]
    }
    
    public func expansion(
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
                    copy.builder = builder.addCheck(op, "\(name)", value)
                    return copy
                }

            static func \(name)(_ op: Vein.ComparisonOperator, _ value: \(type)) -> Self {
                var copy = Self()
                copy.builder = copy.builder.addCheck(op, "\(name)", value)
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
    
    public func expansion(
        of node: AttributeSyntax,
        attachedTo classDecl: ClassDeclSyntax,
        providingAttributesFor varDecl: VariableDeclSyntax,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Find the marker @Relationship attribute on the property
        guard let relationshipAttr = findRelationshipAttribute(in: varDecl) else {
            return []
        }
        
        // Extract the user-defined arguments (inverse, deleteRule, etc.)
        let arguments = relationshipAttr.arguments
        
        // Determine if target type is a collection
        let isMany = isCollection(type: varDecl.bindings.first?.typeAnnotation?.type)
        let wrapperName = isMany ? "_ManyRelationship" : "_OneRelationship"
        
        // Generate the matching property wrapper with passed-through arguments
        let attribute: AttributeSyntax = "@\(raw: wrapperName)(\(raw: arguments?.description ?? ""))"
        return [attribute]
    }
}
public struct DebugDiag: DiagnosticMessage {
    public let message: String
    public var diagnosticID: MessageID { .init(domain: "VeinMacros", id: "debug") }
    public var severity: DiagnosticSeverity { .warning }
}

public enum FieldType {
    case field
    case lazyField
    case relationship
}

extension FieldType {
    func matches(_ variable: VariableDeclSyntax, frameworkName: String) -> Bool {
        return switch self {
            case .field:
                variable.hasAttributeOrMacro(named: "Field")
                || variable.hasAttributeOrMacro(named: "\(frameworkName).Field")
            case .lazyField:
                variable.hasAttributeOrMacro(named: "LazyField")
                || variable.hasAttributeOrMacro(named: "\(frameworkName).LazyField")
            case .relationship:
                variable.hasAttributeOrMacro(named: "Relationship")
                || variable.hasAttributeOrMacro(named: "\(frameworkName).Relationship")
        }
    }
}

extension MemberBlockSyntax {
    func membersWithFieldType(_ type: FieldType, frameworkName: String) -> [VariableDeclSyntax] {
        members.compactMap { (member: MemberBlockItemSyntax) -> VariableDeclSyntax? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                return nil
            }
            
            let hasFieldAttribute = type.matches(varDecl, frameworkName: frameworkName)
            
            return hasFieldAttribute ? varDecl : nil
        }
    }
}

extension Array where Element == VariableDeclSyntax {
    func fields() -> [String: String] {
        var fields = [String: String]()
        for varDecl in self {
            guard let binding = varDecl.bindings.first else { continue }
            guard
                let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                let datatype = binding.typeAnnotation?.description
            else { continue }
            fields[name] = datatype
        }
        return fields
    }
}

extension Dictionary where Key == String, Value == String {
    func initEagerRows() -> String {
        self.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return """
                self.\(key) = try! \(value).init(
                        fromPersistent: \(value).PersistentRepresentation.decode(
                            sqliteValue: fields[\"\(key)\"]!
                        )
                    )!
                """
        }.joined(separator: "\n    ")
    }
}

extension VariableDeclSyntax {
    func hasAttributeOrMacro(named name: String) -> Bool {
        let parts = name.split(separator: ".")
        
        var expectation: [TokenKind] = []
        
        for (i, identifier) in parts.enumerated() {
            expectation.append(.identifier(String(identifier)))
            
            if i < parts.count - 1 {
                expectation.append(.period)
            }
        }
        
        for attribute in attributes {
            switch attribute {
                case .attribute(let attr):
                    if attr.attributeName.tokens(viewMode: .all).map(\.tokenKind) == expectation {
                        return true
                    }
                default:
                    break
            }
        }
        return false
    }
    
    func attributeOrMacro(matching name: String) -> AttributeSyntax? {
        let parts = name.split(separator: ".")
        
        var expectation: [TokenKind] = []
        
        for (i, identifier) in parts.enumerated() {
            expectation.append(.identifier(String(identifier)))
            
            if i < parts.count - 1 {
                expectation.append(.period)
            }
        }
        
        for attribute in attributes {
            switch attribute {
                case .attribute(let attr):
                    if attr.attributeName.tokens(viewMode: .all).map(\.tokenKind) == expectation {
                        return attr
                    }
                default:
                    break
            }
        }
        return nil
    }
}

extension ModelMacroBase {
    func findRelationshipAttribute(in varDecl: VariableDeclSyntax) -> AttributeSyntax? {
        varDecl.attributeOrMacro(matching: "Relationship")
    }
    
    func isCollection(type: TypeSyntax?) -> Bool {
        guard let type = type else { return false }
        
        let typeStr = type.trimmedDescription
        
        // Match syntactic sugar like [Type] or explicit collection types
        return typeStr.hasPrefix("[") ||
        typeStr.hasPrefix("Set<") ||
        typeStr.hasPrefix("Array<")
    }
}
