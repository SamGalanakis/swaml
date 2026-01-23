pub(crate) mod response_handler;

// MODIFIED for ellie-wrapped-embedded: Platform-specific auth modules
// - wasm32: Uses browser SubtleCrypto API via wasm_auth
// - iOS: Uses jsonwebtoken crate via ios_auth (no gcp_auth support)
// - Desktop: Uses gcp_auth crate via std_auth (full GCP auth support)

#[cfg(target_arch = "wasm32")]
pub(super) mod wasm_auth;
#[cfg(target_arch = "wasm32")]
pub(super) use wasm_auth as auth;

#[cfg(target_os = "ios")]
pub(super) mod ios_auth;
#[cfg(target_os = "ios")]
pub(super) use ios_auth as auth;

#[cfg(all(not(target_arch = "wasm32"), not(target_os = "ios")))]
pub(super) mod std_auth;
#[cfg(all(not(target_arch = "wasm32"), not(target_os = "ios")))]
pub(super) use std_auth as auth;

mod types;
mod vertex_client;
pub use vertex_client::VertexClient;
