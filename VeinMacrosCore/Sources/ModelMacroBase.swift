import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation

@_spi(VeinMacros)
public struct ModelMacroBase {
    public init(frameworkName: String) {
        self.frameworkName = frameworkName
    }
    
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
        var predicateInformation: [String] = []
        var fieldInformation: [String] = []
        for (key, value) in lazyFields {
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            let information = "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", false)"
            fieldInformation.append(information)
            predicateInformation.append("case \\.\(key): \(information)")
        }
        for (key, value) in eagerFields {
            let value = value.drop(while: { $0 == " " || $0 == ":" })
            let information = "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", true)"
            fieldInformation.append(information)
            predicateInformation.append("case \\.\(key): \(information)")
        }
        for (key, value) in relationshipFields {
            let relationshipType = "\(value.coreRelationshipType).self"
            // currently only ULID or ULID array is supported
            let value = value.isCollection ? "[ULID]": "ULID?"
            let information = "Vein.FieldInformation(\(value).sqliteTypeName, \"\(key)\", true, \(relationshipType))"
            
            fieldInformation.append(information)
            predicateInformation.append("case \\.\(key): \(information)")
        }
        
        let fieldInformationString = fieldInformation.joined(separator: ",\n    ")
        var predicateInformationString: String
        
        predicateInformation.append("case \\.id: Vein.FieldInformation(ULID.sqliteTypeName, \"id\", true)")
        
        if !predicateInformation.isEmpty {
            predicateInformationString = "switch keyPath {\n        "
            predicateInformationString.append(contentsOf: predicateInformation.joined(separator: "\n        "))
            predicateInformationString.append("\n        default: nil")
            predicateInformationString.append("\n    }")
        } else {
            predicateInformationString = "nil"
        }
        
        // MARK: - inverse field data
        let inverseFieldData: String = relationshipVariables.compactMap {
            guard
                let relationshipAttr = findRelationshipAttribute(in: $0),
                let arguments = relationshipAttr.arguments?.as(LabeledExprListSyntax.self),
                let inverseArg = arguments.first(where: { $0.label?.text == "inverse" }),
                let (root, last) = inverseArg.expression.extractKeyPathComponents(),
                let key = $0.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            else { return nil }
            
            return """
            map[ObjectIdentifier(\(root).self), default: [:]]["\(last)"] = "\(key)"
            """
        }.joined(separator: "\n    ")
        
        
        // MARK: - inits and assembly
        let eagerVarInit = eagerFields.initEagerRows()
        let relationshipInit = relationshipFields.initRelationshipRows()
        
        fieldBodys.append("self._id.model = self")
        let fieldSetup = fieldBodys.joined(separator: "\n    ")
        let fieldAccessorSetup = fieldAccessorBodies.joined(separator: ",\n        ")
        
        let body =
"""
/// The primary ID of the object.
/// Gets  used to reference models in relationships.
/// Immutable after insertion into the context.
@Vein.PrimaryKey
var id: Vein.ULID

required init(id: Vein.ULID, fields: [String: Vein.SQLiteValue]) {
    self.id = id
    \(eagerVarInit)
    \(relationshipInit)
    _setupFields()
}

let _observers = Vein.Atomic([Vein.ULID: () -> Void]())

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

static let _inverseFields = {
    var map = [ObjectIdentifier: [String: String]]()
    \(inverseFieldData)
    return map
}()

static func _predicateInformation(for keyPath: PartialKeyPath<\(className)>) -> Vein.FieldInformation? {
    \(predicateInformationString)
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
           let inverseArg = argumentList.first(where: { $0.label?.text == "inverse" }),
           let (root, last) = inverseArg.expression.extractKeyPathComponents(),
           let typeDecl = varDecl
                .bindings
                .first?
                .typeAnnotation?
                .type
                .description
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: ["?"])
        {
            guard
                typeDecl == root || typeDecl == "[\(root)]" || typeDecl == "Array<\(root)>"
            else {
                throw MacroError.relationshipKeypathDoesNotMatchTypeDeclaration("""
                \(root) is not compatible with \(typeDecl)
                """)
            }
            transformedArguments.append("inverse: \"\(last)\"")
        }
        
        if let argumentList = arguments,
           let deleteruleArg = argumentList.first(where: { $0.label?.text == "deleteRule" })
        { transformedArguments.append(deleteruleArg.description) }
        
        // Determine if target type is a collection
        let isMany = isCollection(type: varDecl.bindings.first?.typeAnnotation?.type)
        let wrapperName = isMany ? "Vein._ManyRelationship" : "Vein._OneRelationship"
        
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
                let datatype = binding.typeAnnotation?.type.trimmedDescription
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
        ?? varDecl.attributeOrMacro(matching: "\(frameworkName).Relationship")
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
    
    var coreRelationshipType: String {
        self
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "Array<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension ExprSyntax {
    func extractKeyPathComponents() -> (root: String, last: String)? {
        // Check if the expression is a KeyPath
        guard let keyPath = self.as(KeyPathExprSyntax.self) else {
            return nil
        }
        
        // Get the last component (the property name)
        guard
            let rootComponent = keyPath.root,
            let lastComponent = keyPath.components.last,
            let lastPropertyComponent = lastComponent.component.as(KeyPathPropertyComponentSyntax.self)
        else { return nil }
        
        return (
            root: rootComponent.trimmedDescription,
            last: lastPropertyComponent.trimmedDescription
        )
    }
}
