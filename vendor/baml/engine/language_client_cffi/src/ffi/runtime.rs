use std::collections::HashMap;

use baml_runtime::BamlRuntime;
use internal_baml_core::feature_flags::FeatureFlags;

use super::*;
use crate::panic::ffi_safe::ffi_safe_ptr;

const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Returns the BAML version as a Buffer containing raw UTF-8 bytes.
/// Caller must free with free_buffer().
#[no_mangle]
pub extern "C" fn version() -> Buffer {
    Buffer::from(VERSION.as_bytes().to_vec())
}

#[allow(clippy::not_unsafe_ptr_arg_deref)]
#[no_mangle]
pub extern "C" fn create_baml_runtime(
    root_path: *const libc::c_char,
    src_files_json: *const libc::c_char,
    env_vars_json: *const libc::c_char,
) -> *const libc::c_void {
    ffi_safe_ptr(|| -> Result<*const libc::c_void, String> {
        // Parse src_files JSON
        let src_files_str = unsafe {
            CStr::from_ptr(src_files_json)
                .to_str()
                .map_err(|e| format!("Invalid UTF-8 in src_files_json: {e}"))?
        };
        let src_files = serde_json::from_str::<HashMap<String, String>>(src_files_str)
            .map_err(|e| format!("Failed to parse src_files JSON: {e}"))?;

        // Parse env_vars JSON
        let env_vars_str = unsafe {
            CStr::from_ptr(env_vars_json)
                .to_str()
                .map_err(|e| format!("Invalid UTF-8 in env_vars_json: {e}"))?
        };
        let env_vars = serde_json::from_str::<HashMap<String, String>>(env_vars_str)
            .map_err(|e| format!("Failed to parse env_vars JSON: {e}"))?;

        // Parse root_path
        let root_path_str = unsafe {
            CStr::from_ptr(root_path)
                .to_str()
                .map_err(|e| format!("Invalid UTF-8 in root_path: {e}"))?
        };

        // Create runtime
        let runtime = BamlRuntime::from_file_content(
            root_path_str,
            &src_files,
            env_vars,
            FeatureFlags::new(),
        )
        .map_err(|e| format!("Failed to create BAML runtime: {e}"))?;

        Ok(Box::into_raw(Box::new(runtime)) as *const libc::c_void)
    })
}

#[no_mangle]
pub extern "C" fn destroy_baml_runtime(runtime: *const libc::c_void) {
    if !runtime.is_null() {
        unsafe {
            let _ = Box::from_raw(runtime as *mut BamlRuntime);
        }
    }
}
