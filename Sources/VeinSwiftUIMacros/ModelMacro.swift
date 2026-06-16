import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation
@_spi(VeinMacros) import VeinMacrosCore

public struct ModelMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    static let frameworkName = "VeinSwiftUI"
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }
        
        let common = try ModelMacroBase(frameworkName: Self.frameworkName).expansion(
            of: node,
            providingMembersOf: classDecl,
            conformingTo: protocols,
            in: context
        )
        
        let specific = """
        let objectWillChange = PassthroughSubject<Void, Never>()

        var notifyOfChanges: () -> Void {
            { [weak self] in
                guard let self else { return }
                for notification in self._observers.value.values {
                    notification()
                }
                self.objectWillChange.send()
            }
        }
        """
        
        return common + [DeclSyntax(stringLiteral: specific)]
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
        
        let common = try ModelMacroBase(frameworkName: Self.frameworkName).expansion(
            of: node,
            attachedTo: classDecl,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )
        
        let specific = try ExtensionDeclSyntax(
            """
            @MainActor
            extension \(raw: type): ObservableObject { }
            """
        )
        
        return common + [specific]
    }

    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingAttributesFor member: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.AttributeSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }
        guard let varDecl = member.as(VariableDeclSyntax.self) else {
            // skip non-variables
            return []
        }
        return try ModelMacroBase(frameworkName: Self.frameworkName).expansion(
            of: node,
            attachedTo: classDecl,
            providingAttributesFor: varDecl,
            in: context
        )
    }
}

public struct RelationshipMarkerMacro: PeerMacro {
    public static func expansion(of node: SwiftSyntax.AttributeSyntax, providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        []
    }
}
