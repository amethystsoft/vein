import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct BetterSyncMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        ModelMacro.self
    ]
}
