import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwamlMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SwamlTypeMacro.self,
        SwamlDynamicMacro.self,
        DescriptionMacro.self,
        AliasMacro.self,
    ]
}
