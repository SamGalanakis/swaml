import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwamlMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        BamlTypeMacro.self,
        BamlDynamicMacro.self,
        DescriptionMacro.self,
        AliasMacro.self,
    ]
}
