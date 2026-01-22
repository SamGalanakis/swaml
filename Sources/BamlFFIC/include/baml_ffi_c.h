// BAML FFI C Wrapper
// Provides C wrappers that convert BAML's struct-by-value returns to output parameters
// Compatible with BAML 0.218.0+

#ifndef BAML_FFI_C_H
#define BAML_FFI_C_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Buffer struct matching BAML's C FFI (16 bytes on 64-bit)
typedef struct {
    const int8_t* ptr;
    size_t len;
} BamlCBuffer;

// Opaque handle to loaded BAML library
typedef struct BamlLibrary BamlLibrary;

// Load the BAML FFI library from the given path
// Returns NULL on failure
BamlLibrary* baml_library_load(const char* path);

// Try to load the BAML FFI library from standard locations
// Returns NULL if not found
BamlLibrary* baml_library_load_default(void);

// Unload the BAML FFI library
void baml_library_unload(BamlLibrary* lib);

// Check if the library is loaded
bool baml_library_is_loaded(BamlLibrary* lib);

// Get version string (caller must free buffer with baml_free_buffer)
void baml_version(BamlLibrary* lib, const int8_t** out_ptr, size_t* out_len);

// Create BAML runtime
// Returns runtime handle or NULL on failure
void* baml_create_runtime(
    BamlLibrary* lib,
    const char* root_path,
    const char* src_files_json,
    const char* env_vars_json
);

// Destroy BAML runtime
void baml_destroy_runtime(BamlLibrary* lib, void* runtime);

// Call a BAML function (synchronous)
// Output is written to out_ptr and out_len
void baml_call_function(
    BamlLibrary* lib,
    void* runtime,
    const char* function_name,
    const int8_t* encoded_args,
    size_t args_len,
    uint32_t call_id,
    const int8_t** out_ptr,
    size_t* out_len
);

// Call a BAML function with streaming
void baml_call_function_stream(
    BamlLibrary* lib,
    void* runtime,
    const char* function_name,
    const int8_t* encoded_args,
    size_t args_len,
    uint32_t call_id,
    const int8_t** out_ptr,
    size_t* out_len
);

// Call an object constructor (creates TypeBuilder, Collector, etc.)
// Returns a buffer containing the object handle
void baml_call_object_constructor(
    BamlLibrary* lib,
    const int8_t* encoded_args,
    size_t args_len,
    const int8_t** out_ptr,
    size_t* out_len
);

// Call an object method
void baml_call_object_method(
    BamlLibrary* lib,
    void* runtime,
    const int8_t* encoded_args,
    size_t args_len,
    const int8_t** out_ptr,
    size_t* out_len
);

// Free a buffer returned by BAML
void baml_free_buffer(BamlLibrary* lib, const int8_t* ptr, size_t len);

// Callback types for async operations
typedef void (*baml_result_callback)(uint32_t call_id, int32_t event_type, const int8_t* data, size_t len);
typedef void (*baml_error_callback)(uint32_t call_id, int32_t error_code, const int8_t* msg, size_t len);
typedef void (*baml_tick_callback)(uint32_t call_id);

// Register callbacks for async operations
void baml_register_callbacks(
    BamlLibrary* lib,
    baml_result_callback result_cb,
    baml_error_callback error_cb,
    baml_tick_callback tick_cb
);

#ifdef __cplusplus
}
#endif

#endif // BAML_FFI_C_H
