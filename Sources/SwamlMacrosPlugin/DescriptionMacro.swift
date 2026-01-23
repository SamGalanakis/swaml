import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro that attaches a description to a property or enum case.
/// This is a peer macro that doesn't generate any code - it just acts as a marker
/// that the @BamlType macro reads during expansion.
public struct DescriptionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro doesn't generate any code - it's just a marker
        // that @BamlType reads during expansion
        return []
    }
}
