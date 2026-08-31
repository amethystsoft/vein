// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import SwiftSyntax
import SwiftSyntaxMacros

class InitializerVisitor: SyntaxVisitor {
    let forbiddenSelfAssignments: Set<String>
    private var localVariableScopes: [[String]] = [[]]
    let context: MacroExpansionContext

    init(forbiddenSelfAssignments: Set<String>, in context: some MacroExpansionContext) {
        self.forbiddenSelfAssignments = forbiddenSelfAssignments
        self.context = context

        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
        localVariableScopes.append([])
        return .visitChildren
    }

    override func visitPost(_ node: CodeBlockSyntax) {
        _ = localVariableScopes.popLast()
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                let localName = pattern.identifier.text

                if var currentScope = localVariableScopes.last {
                    currentScope.append(localName)
                    localVariableScopes[localVariableScopes.count - 1] = currentScope
                }
            }
        }

        return .visitChildren
    }

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)
        guard
            elements.count >= 3,
            let assignmentIndex = elements.firstIndex(where: { $0.is(AssignmentExprSyntax.self)}),
            assignmentIndex > 0
        else {
            return .visitChildren
        }

        let lhs = elements[assignmentIndex - 1]

        if
            let memberAccess = lhs.as(MemberAccessExprSyntax.self),
            let baseDecl = memberAccess.base?.as(DeclReferenceExprSyntax.self),
            baseDecl.baseName.text == "self"
        {
            let assignedPropertyName = memberAccess.declName.baseName.text
            if forbiddenSelfAssignments.contains(assignedPropertyName) {
                context.diagnose(.init(
                    node: Syntax(memberAccess),
                    message: ErrorDiag(
                        message: """
                            Illegal assignment to relationship property in initializer. \
                            Relationships require the model to be managed by a context.
                            """
                    )
                ))
            }
            return .visitChildren
        }

        if let declRef = lhs.as(DeclReferenceExprSyntax.self) {
            let assignedVariableName = declRef.baseName.text

            if forbiddenSelfAssignments.contains(assignedVariableName) {
                let allLocalVariables = localVariableScopes.flatMap(\.self)

                if !allLocalVariables.contains(assignedVariableName) {
                    context.diagnose(.init(
                        node: Syntax(declRef),
                        message: ErrorDiag(
                            message: """
                                Illegal assignment to relationship property in initializer. \
                                Relationships require the model to be managed by a context.
                                """
                        )
                    ))
                }
            }
        }

        return .visitChildren
    }
}
