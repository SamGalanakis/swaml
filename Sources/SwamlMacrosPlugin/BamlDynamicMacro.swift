import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that marks a type as dynamically extensible at runtime.
/// This is a peer macro that doesn't generate any code - it just acts as a marker
/// that the @BamlType macro reads during expansion.
public struct BamlDynamicMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Validate that @BamlDynamic is only applied to enums (or structs for future use)
        if declaration.is(StructDeclSyntax.self) || declaration.is(EnumDeclSyntax.self) {
            // Valid usage - this macro doesn't generate code,
            // it's just a marker that @BamlType reads
            return []
        }

        throw MacroError.message("@BamlDynamic can only be applied to structs and enums")
    }
}
