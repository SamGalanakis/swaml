//! baml-swift CLI
//!
//! A command-line tool for generating Swift code from BAML files.
//!
//! # Usage
//!
//! ```bash
//! baml-swift --input ./baml_src --output ./Sources/BamlClient
//! ```

use std::path::PathBuf;

use anyhow::{Context, Result};
use clap::Parser;

use baml_generator_swift::{parse_baml_dir, GeneratorConfig, SwiftGenerator};

/// Generate Swift code from BAML files
#[derive(Parser)]
#[command(name = "baml-swift")]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to the directory containing .baml files
    #[arg(short, long, default_value = "baml_src")]
    input: PathBuf,

    /// Output directory for generated Swift code
    #[arg(short, long, default_value = "baml_client")]
    output: PathBuf,

    /// Package name for the generated Swift code
    #[arg(short, long, default_value = "BamlClient")]
    package: String,

    /// Generate streaming type variants
    #[arg(long, default_value = "true")]
    streaming: bool,

    /// Verbose output
    #[arg(short, long)]
    verbose: bool,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    if cli.verbose {
        eprintln!("Parsing BAML files from: {}", cli.input.display());
    }

    // Parse BAML files
    let ir = parse_baml_dir(&cli.input)
        .with_context(|| format!("Failed to parse BAML files in: {}", cli.input.display()))?;

    if cli.verbose {
        eprintln!(
            "Found {} enums, {} classes, {} functions, {} type aliases",
            ir.enums.len(),
            ir.classes.len(),
            ir.functions.len(),
            ir.type_aliases.len()
        );
    }

    // Create generator configuration
    let config = GeneratorConfig {
        output_dir: cli.output.to_string_lossy().to_string(),
        package_name: cli.package.clone(),
        generate_streaming: cli.streaming,
        generate_sync: false,
    };

    // Generate Swift code
    let generator = SwiftGenerator::new(config);
    let files = generator
        .generate(&ir)
        .with_context(|| "Failed to generate Swift code")?;

    // Write files to disk
    for (path, content) in files.files().iter() {
        let full_path = PathBuf::from(path);

        // Create parent directory if it doesn't exist
        if let Some(parent) = full_path.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("Failed to create directory: {}", parent.display()))?;
        }

        // Write file
        std::fs::write(&full_path, content)
            .with_context(|| format!("Failed to write file: {}", full_path.display()))?;

        if cli.verbose {
            eprintln!("Generated: {}", path);
        } else {
            println!("{}", path);
        }
    }

    if cli.verbose {
        eprintln!("Successfully generated {} files", files.files().len());
    }

    Ok(())
}
