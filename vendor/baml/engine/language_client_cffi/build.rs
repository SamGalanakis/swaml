use std::path::Path;

fn main() -> std::io::Result<()> {
    println!("running build for baml_cffi");
    // Re-run if any of the proto files change.
    println!("cargo:rerun-if-changed=types/baml/cffi/v1/baml_outbound.proto");
    println!("cargo:rerun-if-changed=types/baml/cffi/v1/baml_inbound.proto");
    println!("cargo:rerun-if-changed=types/baml/cffi/v1/baml_object.proto");
    println!("cargo:rerun-if-changed=types/baml/cffi/v1/baml_object_methods.proto");

    // Re-run build.rs if these files change.
    println!("cargo:rerun-if-changed=cbindgen.toml");
    println!("cargo:rerun-if-changed=src/lib.rs");
    println!("cargo:rerun-if-changed=src/ctypes/baml_type_encode.rs");
    println!("cargo:rerun-if-changed=src/ctypes/baml_value_encode.rs");
    println!("cargo:rerun-if-changed=src/ctypes/baml_type_decode.rs");
    println!("cargo:rerun-if-changed=build.rs");

    unsafe {
        std::env::set_var(
            "PROTOC",
            protoc_bin_vendored::protoc_bin_path()
                .unwrap()
                .to_str()
                .unwrap(),
        );
    }
    let protos = [
        "types/baml/cffi/v1/baml_outbound.proto",
        "types/baml/cffi/v1/baml_inbound.proto",
        "types/baml/cffi/v1/baml_object.proto",
        "types/baml/cffi/v1/baml_object_methods.proto",
    ];

    prost_build::compile_protos(&protos, &["types"])?;

    // Use cbindgen to generate the C header for your Rust library.
    let crate_dir = std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set");

    {
        // Generate header to vendor/baml/include/ for SWAML
        let out_path = Path::new(&crate_dir).join("../../include/baml_ffi.h");

        // Ensure the include directory exists
        if let Some(parent) = out_path.parent() {
            std::fs::create_dir_all(parent).ok();
        }

        let outpath_content =
            std::fs::read_to_string(&out_path).unwrap_or_else(|_| String::from(""));
        let res = cbindgen::Builder::new()
            .with_config(cbindgen::Config::from_file("cbindgen.toml").unwrap())
            .with_crate(".")
            .generate()
            .expect("Failed to generate C header")
            .write_to_file(out_path.clone());
        if std::env::var("CI").is_ok() && res {
            let new_content = std::fs::read_to_string(&out_path).unwrap();
            // Normalize line endings for comparison (Windows CRLF vs Unix LF)
            let normalized_old = outpath_content.replace("\r\n", "\n");
            let normalized_new = new_content.replace("\r\n", "\n");

            if normalized_old != normalized_new {
                println!("New header content: \n==============\n{new_content}");
                println!("\n\n");
                println!("Old header content: \n==============\n{outpath_content}");
                panic!("cbindgen generated a diff");
            }
        }
    }

    Ok(())
}
