import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation
import CommonVeinMacroLogic

public struct ModelMacro: MemberMacro, ExtensionMacro, PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingMembersOf declaration: some SwiftSyntax.DeclGroupSyntax,
        conformingTo protocols: [SwiftSyntax.TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }
        
        let common = try CommonVeinMacroLogic.Model.expansion(
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
        
        return try CommonVeinMacroLogic.Model.expansion(
            of: node,
            attachedTo: classDecl,
            providingExtensionsOf: type,
            conformingTo: protocols,
            in: context
        )
    }
    
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }
        
        return try CommonVeinMacroLogic.Model.expansion(
            of: node,
            providingPeersOf: classDecl,
            in: context
        )
    }
}

