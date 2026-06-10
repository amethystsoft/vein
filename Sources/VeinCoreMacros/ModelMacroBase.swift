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
        var allFieldNames = Array(eagerFields.keys) + Array(relationshipFields.keys)
        allFieldNames.append(contentsOf: lazyFields.keys)
        
        var fieldBodys = [String]()
        var fieldAccessorBodies = [String]()
        
        fieldAccessorBodies.append("self._id")
        
        for name in allFieldNames {
            // This is not needed in every case, but its handy for internal ones
            // not using the wrappedValue.
            fieldBodys.append("self._\(name).model = self")
            fieldBodys.append("self._\(name).key = \"\(name)\"")
            fieldAccessorBodies.append("self._\(name)")
        }
        
        // MARK: - _relationship accessor
        let relationshipAccessorSetup = relationshipFields.map { name, _ in
            "self._\(name)"
        }.joined(separator: ",\n        ")
        
        // MARK: - Field information
        var fieldInformation = lazyFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", false)"
        }
        fieldInformation.append(contentsOf: eagerFields.map { key, value in
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            return "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", true)"
        })
        fieldInformation.append(contentsOf: relationshipFields.map { key, value in
            // currently only ULID or ULID array is supported
            let value = value.isCollection ? "[ULID]": "ULID?"
            return "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", true)"
        })
        
        let fieldInformationString = fieldInformation.joined(separator: ",\n    ")
        
        // MARK: - inits and assembly
        let eagerVarInit = eagerFields.initEagerRows()
        let relationshipInit = relationshipFields.initRelationshipRows()
        
        fieldBodys.append("self._id.model = self")
        let fieldSetup = fieldBodys.joined(separator: "\n    ")
        let fieldAccessorSetup = fieldAccessorBodies.joined(separator: ",\n        ")
        
        let body =
"""
    typealias _PredicateHelper = _\(className)PredicateHelper

/// The primary ID of the object.
/// Gets  used to reference models in relationships.
/// Immutable after insertion into the context.
@PrimaryKey
var id: ULID

required init(id: ULID, fields: [String: Vein.SQLiteValue]) {
    self.id = id
    \(eagerVarInit)
    \(relationshipInit)
    _setupFields()
}

/// Sets required properties for @Field values.
/// Gets generated automatically by @Model.
public func _setupFields() {
    \(fieldSetup)
}

var context: Vein.ManagedObjectContext? = nil

/// Whether a model is prepared to be deleted.
///
/// Reading this variable is safe, but it should never be set outside of Vein.
var _isPreparedForDeletion = false

var _fields: [any Vein.FieldBase] {
    [
        \(fieldAccessorSetup)
    ]
}

var _relationships: [any Vein.PersistedRelationship] {
    [
        \(relationshipAccessorSetup)
    ]
}

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
        let arguments = relationshipAttr.arguments?.as(LabeledExprListSyntax.self)
        
        var transformedArguments: [String] = []
        
        if let argumentList = arguments,
           let inverseArg = argumentList.first(where: { $0.label?.text == "inverse" })/*,
           let inversePropertyName = inverseArg.expression.extractKeyPathPropertyName()*/
        {
            // uncomment once keypath is used again with runtime link inference
            // transformedArguments.append("inverse: \"\(inversePropertyName)\"")
            transformedArguments.append(inverseArg.description.trimmingCharacters(in: [",", " "]))
        }
        
        if let argumentList = arguments,
           let deleteruleArg = argumentList.first(where: { $0.label?.text == "deleteRule" })
        { transformedArguments.append(deleteruleArg.description) }
        
        // Determine if target type is a collection
        let isMany = isCollection(type: varDecl.bindings.first?.typeAnnotation?.type)
        let wrapperName = isMany ? "_ManyRelationship" : "_OneRelationship"
        
        let argumentString = transformedArguments.joined(separator: ", ")
        
        // Generate the matching property wrapper with passed-through arguments
        let attribute: AttributeSyntax = "@\(raw: wrapperName)(\(raw: argumentString))"
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
    
    func initRelationshipRows() -> String {
        self.map { key, value in
            let idType = value.isCollection ? "[ULID]": "ULID?"
            return """
                self._\(key).persistableValue = try! \(idType).init(
                        fromPersistent: \(idType).PersistentRepresentation.decode(
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

        return typeStr.isCollection
    }
}

extension String {
    var isCollection: Bool {
        let modified = self.drop(while: { $0 == " " || $0 == ":" })
        return modified.hasPrefix("[") || modified.hasPrefix("Array<")
    }
}

extension ExprSyntax {
    func extractKeyPathPropertyName() -> String? {
        // Check if the expression is a KeyPath
        guard let keyPath = self.as(KeyPathExprSyntax.self) else {
            return nil
        }
        
        // Get the last component (the property name)
        guard let lastComponent = keyPath.components.last,
              let propertyComponent = lastComponent.component.as(KeyPathPropertyComponentSyntax.self) else {
            return nil
        }
        
        return propertyComponent.declName.baseName.text
    }
}
