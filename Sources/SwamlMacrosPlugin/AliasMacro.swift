import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that provides an alternative name for a property in LLM output.
/// This is a peer macro that doesn't generate any code - it just acts as a marker
/// that the @SwamlType macro reads during expansion.
public struct AliasMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro doesn't generate any code - it's just a marker
        // that @SwamlType reads during expansion
        return []
    }
}
