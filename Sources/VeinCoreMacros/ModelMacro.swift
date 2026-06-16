import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation
@_spi(VeinMacros) import VeinMacrosCore

public struct ModelMacro: MemberMacro, ExtensionMacro, MemberAttributeMacro {
    static let frameworkName = "VeinCore"
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
        var notifyOfChanges: () -> Void {
            return {}
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
        
        return try ModelMacroBase(frameworkName: Self.frameworkName).expansion(
            of: node,
            attachedTo: classDecl,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )
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
