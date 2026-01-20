import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct VeinMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        ModelMacro.self
    ]
}
