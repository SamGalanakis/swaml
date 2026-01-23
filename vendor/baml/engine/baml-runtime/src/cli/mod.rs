pub mod check;
pub(crate) mod dotenv;
pub mod dump_intermediate;
pub mod generate;
pub mod init;
pub mod testing;

// MODIFIED for ellie-wrapped-embedded: Desktop-only CLI modules
// These use TUI libs (ratatui, crossterm), file watching (notify), or web server (axum)
// that don't work on iOS
#[cfg(all(not(target_arch = "wasm32"), not(target_os = "ios")))]
pub mod dev;
#[cfg(all(not(target_arch = "wasm32"), not(target_os = "ios")))]
pub mod init_ui;
#[cfg(all(not(target_arch = "wasm32"), not(target_os = "ios")))]
pub mod optimize;
#[cfg(all(not(target_arch = "wasm32"), not(target_os = "ios")))]
pub mod repl;
#[cfg(all(not(target_arch = "wasm32"), not(target_os = "ios")))]
pub mod serve;

use internal_baml_core::configuration::GeneratorOutputType;

/// Default values for the CLI to use.
///
/// We ship different variants of the CLI today:
///
///   - `baml-cli` as bundled with the Python package
///   - `baml-cli` as bundled with the NPM package
///   - `baml-cli` as bundled with the Ruby gem
///
/// Each of these ship with different defaults, as appropriate for
/// the language that they're bundled with.
#[derive(Clone, Copy, Debug)]
pub struct RuntimeCliDefaults {
    pub output_type: GeneratorOutputType,
}
