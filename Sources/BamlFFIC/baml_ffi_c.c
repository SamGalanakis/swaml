// BAML FFI C Wrapper Implementation
// Uses dlopen/dlsym to dynamically load BAML library and handle struct returns

#include "include/baml_ffi_c.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Internal library structure holding function pointers
struct BamlLibrary {
    void* handle;

    // Function pointers
    void* (*create_runtime)(const char*, const char*, const char*);
    void (*destroy_runtime)(const void*);
    BamlCBuffer (*call_function)(const void*, const char*, const int8_t*, size_t, uint32_t);
    BamlCBuffer (*call_function_stream)(const void*, const char*, const int8_t*, size_t, uint32_t);
    BamlCBuffer (*call_object_constructor)(const int8_t*, size_t);
    BamlCBuffer (*call_object_method)(const void*, const int8_t*, size_t);
    void (*free_buffer)(const int8_t*, size_t);
    BamlCBuffer (*version)(void);
    void (*register_callbacks)(
        void (*)(uint32_t, int32_t, const int8_t*, size_t),
        void (*)(uint32_t, int32_t, const int8_t*, size_t),
        void (*)(uint32_t)
    );
};

// Load all symbols from the library
static bool load_symbols(BamlLibrary* lib) {
    if (!lib || !lib->handle) return false;

    lib->create_runtime = dlsym(lib->handle, "create_baml_runtime");
    lib->destroy_runtime = dlsym(lib->handle, "destroy_baml_runtime");
    lib->call_function = dlsym(lib->handle, "call_function_from_c");
    lib->call_function_stream = dlsym(lib->handle, "call_function_stream_from_c");
    lib->call_object_constructor = dlsym(lib->handle, "call_object_constructor");
    lib->call_object_method = dlsym(lib->handle, "call_object_method");
    lib->free_buffer = dlsym(lib->handle, "free_buffer");
    lib->version = dlsym(lib->handle, "version");
    lib->register_callbacks = dlsym(lib->handle, "register_callbacks");

    // At minimum we need create_runtime and call_function
    return lib->create_runtime != NULL && lib->call_function != NULL;
}

BamlLibrary* baml_library_load(const char* path) {
    if (!path) return NULL;

    void* handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        return NULL;
    }

    BamlLibrary* lib = calloc(1, sizeof(BamlLibrary));
    if (!lib) {
        dlclose(handle);
        return NULL;
    }

    lib->handle = handle;

    if (!load_symbols(lib)) {
        dlclose(handle);
        free(lib);
        return NULL;
    }

    return lib;
}

BamlLibrary* baml_library_load_default(void) {
    // Try common library locations
#if defined(__APPLE__)
    const char* paths[] = {
        "libbaml_ffi.dylib",
        "./libbaml_ffi.dylib",
        "./lib/libbaml_ffi.dylib",
        "/usr/local/lib/libbaml_ffi.dylib",
        "BamlFFI.framework/BamlFFI",
        NULL
    };
#elif defined(__linux__)
    const char* paths[] = {
        "libbaml_ffi.so",
        "./libbaml_ffi.so",
        "./lib/libbaml_ffi.so",
        "/usr/local/lib/libbaml_ffi.so",
        "/usr/lib/libbaml_ffi.so",
        NULL
    };
#else
    const char* paths[] = { NULL };
#endif

    for (int i = 0; paths[i] != NULL; i++) {
        BamlLibrary* lib = baml_library_load(paths[i]);
        if (lib) return lib;
    }

    return NULL;
}

void baml_library_unload(BamlLibrary* lib) {
    if (!lib) return;

    if (lib->handle) {
        dlclose(lib->handle);
    }
    free(lib);
}

bool baml_library_is_loaded(BamlLibrary* lib) {
    return lib != NULL && lib->handle != NULL;
}

void baml_version(BamlLibrary* lib, const int8_t** out_ptr, size_t* out_len) {
    if (!lib || !lib->version || !out_ptr || !out_len) {
        if (out_ptr) *out_ptr = NULL;
        if (out_len) *out_len = 0;
        return;
    }

    BamlCBuffer result = lib->version();
    *out_ptr = result.ptr;
    *out_len = result.len;
}

void* baml_create_runtime(
    BamlLibrary* lib,
    const char* root_path,
    const char* src_files_json,
    const char* env_vars_json
) {
    if (!lib || !lib->create_runtime) return NULL;
    return lib->create_runtime(root_path, src_files_json, env_vars_json);
}

void baml_destroy_runtime(BamlLibrary* lib, void* runtime) {
    if (!lib || !lib->destroy_runtime || !runtime) return;
    lib->destroy_runtime(runtime);
}

void baml_call_function(
    BamlLibrary* lib,
    void* runtime,
    const char* function_name,
    const int8_t* encoded_args,
    size_t args_len,
    uint32_t call_id,
    const int8_t** out_ptr,
    size_t* out_len
) {
    if (!lib || !lib->call_function || !runtime || !out_ptr || !out_len) {
        if (out_ptr) *out_ptr = NULL;
        if (out_len) *out_len = 0;
        return;
    }

    BamlCBuffer result = lib->call_function(runtime, function_name, encoded_args, args_len, call_id);
    *out_ptr = result.ptr;
    *out_len = result.len;
}

void baml_call_function_stream(
    BamlLibrary* lib,
    void* runtime,
    const char* function_name,
    const int8_t* encoded_args,
    size_t args_len,
    uint32_t call_id,
    const int8_t** out_ptr,
    size_t* out_len
) {
    if (!lib || !lib->call_function_stream || !runtime || !out_ptr || !out_len) {
        if (out_ptr) *out_ptr = NULL;
        if (out_len) *out_len = 0;
        return;
    }

    BamlCBuffer result = lib->call_function_stream(runtime, function_name, encoded_args, args_len, call_id);
    *out_ptr = result.ptr;
    *out_len = result.len;
}

void baml_call_object_constructor(
    BamlLibrary* lib,
    const int8_t* encoded_args,
    size_t args_len,
    const int8_t** out_ptr,
    size_t* out_len
) {
    if (!lib || !lib->call_object_constructor || !out_ptr || !out_len) {
        if (out_ptr) *out_ptr = NULL;
        if (out_len) *out_len = 0;
        return;
    }

    BamlCBuffer result = lib->call_object_constructor(encoded_args, args_len);
    *out_ptr = result.ptr;
    *out_len = result.len;
}

void baml_call_object_method(
    BamlLibrary* lib,
    void* runtime,
    const int8_t* encoded_args,
    size_t args_len,
    const int8_t** out_ptr,
    size_t* out_len
) {
    if (!lib || !lib->call_object_method || !runtime || !out_ptr || !out_len) {
        if (out_ptr) *out_ptr = NULL;
        if (out_len) *out_len = 0;
        return;
    }

    BamlCBuffer result = lib->call_object_method(runtime, encoded_args, args_len);
    *out_ptr = result.ptr;
    *out_len = result.len;
}

void baml_free_buffer(BamlLibrary* lib, const int8_t* ptr, size_t len) {
    if (!lib || !lib->free_buffer || !ptr) return;
    lib->free_buffer(ptr, len);
}

void baml_register_callbacks(
    BamlLibrary* lib,
    baml_result_callback result_cb,
    baml_error_callback error_cb,
    baml_tick_callback tick_cb
) {
    if (!lib || !lib->register_callbacks) return;
    lib->register_callbacks(result_cb, error_cb, tick_cb);
}
