// MODIFIED for ellie-wrapped-embedded: iOS-specific Vertex auth implementation
// Uses jsonwebtoken crate instead of gcp_auth, since gcp_auth doesn't work on iOS.
// Only supports explicit credentials (service account JSON), not system default.

use std::sync::Arc;

use anyhow::{Context, Result};
use internal_llm_client::vertex::ResolvedGcpAuthStrategy;
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use serde::{Deserialize, Serialize};

pub struct VertexAuth(ServiceAccount);

pub struct Token(String);

impl Token {
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl VertexAuth {
    pub async fn get_or_create(auth_strategy: &ResolvedGcpAuthStrategy) -> Result<Arc<VertexAuth>> {
        let auth = Arc::new(Self::new(auth_strategy).await?);
        Ok(auth)
    }

    pub async fn new(auth_strategy: &ResolvedGcpAuthStrategy) -> Result<Self> {
        match auth_strategy {
            ResolvedGcpAuthStrategy::MaybeFilePath(path) => {
                // Read file and parse as JSON
                let content = std::fs::read_to_string(path)
                    .context(format!("Failed to read credentials file: {}", path))?;
                let service_account: ServiceAccount = serde_json::from_str(&content)
                    .context("Failed to parse credentials file as GCP service account JSON")?;
                Ok(Self(service_account))
            }
            ResolvedGcpAuthStrategy::StringContainingJson(str) => {
                if str.starts_with("$") {
                    anyhow::bail!("Failed to resolve environment variable: {}", str);
                }
                let service_account: ServiceAccount = serde_json::from_str(str)
                    .context("Failed to parse credentials as GCP service account JSON")?;
                Ok(Self(service_account))
            }
            ResolvedGcpAuthStrategy::JsonObject(json) => {
                let service_account: ServiceAccount = serde_json::from_value(
                    serde_json::to_value(json)
                        .context("Failed to serialize credentials")?,
                )
                .context("Failed to parse credentials as GCP service account JSON")?;
                Ok(Self(service_account))
            }
            ResolvedGcpAuthStrategy::SystemDefault => {
                anyhow::bail!(
                    "SystemDefault GCP authentication is not supported on iOS. \
                     Please provide explicit credentials via the 'credentials' option."
                )
            }
        }
    }

    pub async fn token(&self, _scopes: &[&str]) -> Result<Arc<Token>> {
        let token = self.0.get_oauth2_token().await?;
        Ok(Arc::new(token))
    }

    pub async fn project_id(&self) -> Result<Arc<str>> {
        Ok(self.0.project_id.clone().into())
    }
}

fn parse_token_response(response: &str) -> Result<Token> {
    let res: serde_json::Value =
        serde_json::from_str(response).context("Failed to parse token response as JSON")?;

    Ok(Token(
        res.as_object()
            .context("Token exchange did not return a JSON object")?
            .get("access_token")
            .context("Access token not found in response")?
            .as_str()
            .context("Access token is not a string")?
            .to_string(),
    ))
}

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    iss: String,
    scope: String,
    aud: String,
    exp: i64,
    iat: i64,
}

const DEFAULT_SCOPE: &str = "https://www.googleapis.com/auth/cloud-platform";

impl Claims {
    fn from_service_account(service_account: &ServiceAccount) -> Claims {
        let now = chrono::Utc::now();
        Claims {
            iss: service_account.client_email.clone(),
            scope: DEFAULT_SCOPE.to_string(),
            aud: service_account.token_uri.clone(),
            exp: (now + chrono::Duration::hours(1)).timestamp(),
            iat: now.timestamp(),
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct ServiceAccount {
    pub token_uri: String,
    pub project_id: String,
    pub client_email: String,
    pub private_key: String,
}

impl ServiceAccount {
    async fn get_oauth2_token(&self) -> Result<Token> {
        let claims = Claims::from_service_account(self);

        // Use jsonwebtoken crate for JWT encoding
        let header = Header::new(Algorithm::RS256);
        let key = EncodingKey::from_rsa_pem(self.private_key.as_bytes())
            .context("Failed to parse private key as RSA PEM")?;
        let jwt = encode(&header, &claims, &key)
            .context("Failed to encode JWT")?;

        // Make the token request
        let client = reqwest::Client::new();
        let params = [
            ("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            ("assertion", &jwt),
        ];
        let res = client
            .post(&self.token_uri)
            .form(&params)
            .send()
            .await?
            .text()
            .await?;

        parse_token_response(&res).context(format!("OAuth2 access token request failed: {res}"))
    }
}
