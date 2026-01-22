//! Integration tests using actual BAML file scenarios
//!
//! These tests create IR based on real BAML file patterns and verify
//! that the generated Swift code is correct.

use baml_generator_swift::*;

/// Create IR for the sentiment.baml fixture
fn sentiment_ir() -> BamlIR {
    BamlIR {
        enums: vec![EnumDef {
            name: "Sentiment".to_string(),
            docstring: Some("Sentiment classification".to_string()),
            values: vec![
                EnumValueDef {
                    name: "HAPPY".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "SAD".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "NEUTRAL".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "ANGRY".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "EXCITED".to_string(),
                    alias: Some("Very Excited".to_string()),
                    docstring: None,
                },
            ],
            dynamic: false,
        }],
        classes: vec![ClassDef {
            name: "SentimentResult".to_string(),
            docstring: None,
            fields: vec![
                FieldDef {
                    name: "sentiment".to_string(),
                    field_type: FieldType::Enum("Sentiment".to_string()),
                    docstring: None,
                },
                FieldDef {
                    name: "confidence".to_string(),
                    field_type: FieldType::Float,
                    docstring: None,
                },
                FieldDef {
                    name: "explanation".to_string(),
                    field_type: FieldType::Optional(Box::new(FieldType::String)),
                    docstring: None,
                },
            ],
            has_dynamic_fields: false,
        }],
        functions: vec![FunctionDef {
            name: "ClassifySentiment".to_string(),
            docstring: Some("Classify the sentiment of text".to_string()),
            params: vec![ParamDef {
                name: "text".to_string(),
                param_type: FieldType::String,
                docstring: None,
            }],
            return_type: FieldType::Class("SentimentResult".to_string()),
            default_client: Some("default".to_string()),
            prompt: Some("Classify the sentiment of: {{ text }}".to_string()),
        }],
        type_aliases: vec![],
        clients: vec![ClientConfigSwift {
            name: "default".to_string(),
            provider: "openai".to_string(),
            model: "gpt-4".to_string(),
            options: indexmap::IndexMap::new(),
        }],
    }
}

/// Create IR for the user_profile.baml fixture
fn user_profile_ir() -> BamlIR {
    BamlIR {
        enums: vec![EnumDef {
            name: "AccountStatus".to_string(),
            docstring: None,
            values: vec![
                EnumValueDef {
                    name: "ACTIVE".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "INACTIVE".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "SUSPENDED".to_string(),
                    alias: None,
                    docstring: None,
                },
                EnumValueDef {
                    name: "PENDING_VERIFICATION".to_string(),
                    alias: None,
                    docstring: None,
                },
            ],
            dynamic: false,
        }],
        classes: vec![
            ClassDef {
                name: "Address".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "street_address".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "city".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "state".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "postal_code".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "country".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "SocialMedia".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "platform".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "handle".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "url".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "followers".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::Int)),
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "UserProfile".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "user_id".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "first_name".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "last_name".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "email".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "age".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::Int)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "is_verified".to_string(),
                        field_type: FieldType::Bool,
                        docstring: None,
                    },
                    FieldDef {
                        name: "account_status".to_string(),
                        field_type: FieldType::Enum("AccountStatus".to_string()),
                        docstring: None,
                    },
                    FieldDef {
                        name: "addresses".to_string(),
                        field_type: FieldType::List(Box::new(FieldType::Class(
                            "Address".to_string(),
                        ))),
                        docstring: None,
                    },
                    FieldDef {
                        name: "social_links".to_string(),
                        field_type: FieldType::List(Box::new(FieldType::Class(
                            "SocialMedia".to_string(),
                        ))),
                        docstring: None,
                    },
                    FieldDef {
                        name: "tags".to_string(),
                        field_type: FieldType::List(Box::new(FieldType::String)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "metadata".to_string(),
                        field_type: FieldType::Map(
                            Box::new(FieldType::String),
                            Box::new(FieldType::String),
                        ),
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
        ],
        functions: vec![
            FunctionDef {
                name: "ExtractUserProfile".to_string(),
                docstring: None,
                params: vec![
                    ParamDef {
                        name: "raw_text".to_string(),
                        param_type: FieldType::String,
                        docstring: None,
                    },
                    ParamDef {
                        name: "include_social".to_string(),
                        param_type: FieldType::Bool,
                        docstring: None,
                    },
                ],
                return_type: FieldType::Class("UserProfile".to_string()),
                default_client: None,
                prompt: None,
            },
            FunctionDef {
                name: "GetUsersByStatus".to_string(),
                docstring: None,
                params: vec![ParamDef {
                    name: "status".to_string(),
                    param_type: FieldType::Enum("AccountStatus".to_string()),
                    docstring: None,
                }],
                return_type: FieldType::List(Box::new(FieldType::Class("UserProfile".to_string()))),
                default_client: None,
                prompt: None,
            },
        ],
        type_aliases: vec![],
        clients: vec![],
    }
}

/// Create IR for the content_types.baml fixture (with unions)
fn content_types_ir() -> BamlIR {
    BamlIR {
        enums: vec![],
        classes: vec![
            ClassDef {
                name: "TextContent".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "body".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "word_count".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                    FieldDef {
                        name: "language".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "ImageContent".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "url".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "alt_text".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "width".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                    FieldDef {
                        name: "height".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "VideoContent".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "url".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "duration_seconds".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                    FieldDef {
                        name: "thumbnail_url".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "CodeBlock".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "code".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "language".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "line_count".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "ContentItem".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "id".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "title".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "content".to_string(),
                        // Union of TextContent | ImageContent | VideoContent | CodeBlock
                        field_type: FieldType::Union(vec![
                            FieldType::Class("TextContent".to_string()),
                            FieldType::Class("ImageContent".to_string()),
                            FieldType::Class("VideoContent".to_string()),
                            FieldType::Class("CodeBlock".to_string()),
                        ]),
                        docstring: None,
                    },
                    FieldDef {
                        name: "created_at".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "is_published".to_string(),
                        field_type: FieldType::Bool,
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "ContentFeed".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "items".to_string(),
                        field_type: FieldType::List(Box::new(FieldType::Class(
                            "ContentItem".to_string(),
                        ))),
                        docstring: None,
                    },
                    FieldDef {
                        name: "total_count".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                    FieldDef {
                        name: "has_more".to_string(),
                        field_type: FieldType::Bool,
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
        ],
        functions: vec![
            FunctionDef {
                name: "AnalyzeContent".to_string(),
                docstring: None,
                params: vec![ParamDef {
                    name: "content".to_string(),
                    param_type: FieldType::Union(vec![
                        FieldType::Class("TextContent".to_string()),
                        FieldType::Class("ImageContent".to_string()),
                    ]),
                    docstring: None,
                }],
                return_type: FieldType::String,
                default_client: None,
                prompt: None,
            },
            FunctionDef {
                name: "GetContentFeed".to_string(),
                docstring: None,
                params: vec![
                    ParamDef {
                        name: "page".to_string(),
                        param_type: FieldType::Int,
                        docstring: None,
                    },
                    ParamDef {
                        name: "limit".to_string(),
                        param_type: FieldType::Int,
                        docstring: None,
                    },
                ],
                return_type: FieldType::Class("ContentFeed".to_string()),
                default_client: None,
                prompt: None,
            },
        ],
        type_aliases: vec![],
        clients: vec![],
    }
}

/// Create IR for the ecommerce.baml fixture
fn ecommerce_ir() -> BamlIR {
    BamlIR {
        enums: vec![
            EnumDef {
                name: "OrderStatus".to_string(),
                docstring: None,
                values: vec![
                    EnumValueDef {
                        name: "PENDING".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "PROCESSING".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "SHIPPED".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "DELIVERED".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "CANCELLED".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "REFUNDED".to_string(),
                        alias: None,
                        docstring: None,
                    },
                ],
                dynamic: false,
            },
            EnumDef {
                name: "PaymentMethod".to_string(),
                docstring: None,
                values: vec![
                    EnumValueDef {
                        name: "CREDIT_CARD".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "DEBIT_CARD".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "PAYPAL".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "APPLE_PAY".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "GOOGLE_PAY".to_string(),
                        alias: None,
                        docstring: None,
                    },
                    EnumValueDef {
                        name: "BANK_TRANSFER".to_string(),
                        alias: None,
                        docstring: None,
                    },
                ],
                dynamic: false,
            },
        ],
        classes: vec![
            ClassDef {
                name: "Money".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "amount".to_string(),
                        field_type: FieldType::Float,
                        docstring: None,
                    },
                    FieldDef {
                        name: "currency".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "ProductVariant".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "variant_id".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "sku".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "name".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "price".to_string(),
                        field_type: FieldType::Class("Money".to_string()),
                        docstring: None,
                    },
                    FieldDef {
                        name: "inventory_count".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                    FieldDef {
                        name: "attributes".to_string(),
                        field_type: FieldType::Map(
                            Box::new(FieldType::String),
                            Box::new(FieldType::String),
                        ),
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "Product".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "product_id".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "name".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "description".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "base_price".to_string(),
                        field_type: FieldType::Class("Money".to_string()),
                        docstring: None,
                    },
                    FieldDef {
                        name: "variants".to_string(),
                        field_type: FieldType::List(Box::new(FieldType::Class(
                            "ProductVariant".to_string(),
                        ))),
                        docstring: None,
                    },
                    FieldDef {
                        name: "categories".to_string(),
                        field_type: FieldType::List(Box::new(FieldType::String)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "is_available".to_string(),
                        field_type: FieldType::Bool,
                        docstring: None,
                    },
                    FieldDef {
                        name: "rating".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::Float)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "review_count".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
            ClassDef {
                name: "ShippingAddress".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "recipient_name".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "street_line_1".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "street_line_2".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "city".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "state".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                    FieldDef {
                        name: "postal_code".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "country".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "phone".to_string(),
                        field_type: FieldType::Optional(Box::new(FieldType::String)),
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            },
        ],
        functions: vec![FunctionDef {
            name: "CalculateShipping".to_string(),
            docstring: None,
            params: vec![ParamDef {
                name: "destination".to_string(),
                param_type: FieldType::Class("ShippingAddress".to_string()),
                docstring: None,
            }],
            return_type: FieldType::Class("Money".to_string()),
            default_client: None,
            prompt: None,
        }],
        type_aliases: vec![],
        clients: vec![],
    }
}

// ============================================================================
// Sentiment Tests
// ============================================================================

mod sentiment_tests {
    use super::*;

    #[test]
    fn test_sentiment_enum_generation() {
        let ir = sentiment_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // Check enum declaration
        assert!(types.contains("public enum Sentiment: String, Codable, Sendable, CaseIterable, Equatable"));

        // Check all cases are present (lowercased)
        assert!(types.contains("case happy"));
        assert!(types.contains("case sad"));
        assert!(types.contains("case neutral"));
        assert!(types.contains("case angry"));

        // Check alias is handled correctly
        assert!(types.contains("case excited = \"Very Excited\""));
    }

    #[test]
    fn test_sentiment_result_struct() {
        let ir = sentiment_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // Check struct declaration
        assert!(types.contains("public struct SentimentResult: Codable, Sendable, Equatable"));

        // Check fields with correct types
        assert!(types.contains("public let sentiment: Sentiment"));
        assert!(types.contains("public let confidence: Double"));
        assert!(types.contains("public let explanation: String?"));
    }

    #[test]
    fn test_classify_sentiment_function() {
        let ir = sentiment_ir();
        let files = generate_swift(&ir).unwrap();
        let client = files.get("baml_client/BamlClient.swift").unwrap();

        // Check function signature
        assert!(client.contains("func classifySentiment"));

        // Check parameter
        assert!(client.contains("text: String"));

        // Check return type
        assert!(client.contains("-> SentimentResult"));
    }

    #[test]
    fn test_sentiment_client_config() {
        let ir = sentiment_ir();
        let files = generate_swift(&ir).unwrap();
        let globals = files.get("baml_client/Globals.swift").unwrap();

        // Check provider initialization
        assert!(globals.contains(".openAI"));
        assert!(globals.contains("gpt-4"));
    }
}

// ============================================================================
// User Profile Tests
// ============================================================================

mod user_profile_tests {
    use super::*;

    #[test]
    fn test_address_struct_with_snake_case() {
        let ir = user_profile_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // Check struct declaration
        assert!(types.contains("public struct Address: Codable, Sendable, Equatable"));

        // Check camelCase conversion
        assert!(types.contains("public let streetAddress: String"));
        assert!(types.contains("public let postalCode: String"));

        // Check CodingKeys are generated for snake_case fields
        assert!(types.contains("case streetAddress = \"street_address\""));
        assert!(types.contains("case postalCode = \"postal_code\""));
    }

    #[test]
    fn test_user_profile_complex_types() {
        let ir = user_profile_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // Check array types
        assert!(types.contains("public let addresses: [Address]"));
        assert!(types.contains("public let socialLinks: [SocialMedia]"));
        assert!(types.contains("public let tags: [String]"));

        // Check map type
        assert!(types.contains("public let metadata: [String: String]"));

        // Check optional types
        assert!(types.contains("public let age: Int?"));
        assert!(types.contains("public let state: String?"));

        // Check enum reference
        assert!(types.contains("public let accountStatus: AccountStatus"));
    }

    #[test]
    fn test_account_status_enum() {
        let ir = user_profile_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        assert!(types.contains("public enum AccountStatus"));
        assert!(types.contains("case active"));
        assert!(types.contains("case inactive"));
        assert!(types.contains("case suspended"));
        assert!(types.contains("case pendingVerification"));

        // Check raw value mapping for PENDING_VERIFICATION
        assert!(types.contains("case pendingVerification = \"PENDING_VERIFICATION\""));
    }

    #[test]
    fn test_function_with_multiple_params() {
        let ir = user_profile_ir();
        let files = generate_swift(&ir).unwrap();
        let client = files.get("baml_client/BamlClient.swift").unwrap();

        // Check function with multiple parameters
        assert!(client.contains("func extractUserProfile"));
        assert!(client.contains("rawText: String"));
        assert!(client.contains("includeSocial: Bool"));
        assert!(client.contains("-> UserProfile"));
    }

    #[test]
    fn test_function_returning_array() {
        let ir = user_profile_ir();
        let files = generate_swift(&ir).unwrap();
        let client = files.get("baml_client/BamlClient.swift").unwrap();

        // Check function returning array
        assert!(client.contains("func getUsersByStatus"));
        assert!(client.contains("status: AccountStatus"));
        assert!(client.contains("-> [UserProfile]"));
    }
}

// ============================================================================
// Content Types Tests (Unions)
// ============================================================================

mod content_types_tests {
    use super::*;

    #[test]
    fn test_union_type_generates_swift_enum() {
        let ir = content_types_ir();
        let files = generate_swift(&ir).unwrap();

        // Check that Unions.swift is generated
        let unions = files.get("baml_client/Unions.swift");
        assert!(unions.is_some(), "Unions.swift should be generated for union types");

        let unions = unions.unwrap();

        // Check union enum declaration
        assert!(unions.contains("public enum"));
        assert!(unions.contains("Codable"));
    }

    #[test]
    fn test_content_item_with_union_field() {
        let ir = content_types_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // ContentItem should have a union field
        assert!(types.contains("public struct ContentItem"));

        // Other non-union fields should be present
        assert!(types.contains("public let id: String"));
        assert!(types.contains("public let title: String"));
        assert!(types.contains("public let isPublished: Bool"));
    }

    #[test]
    fn test_content_classes() {
        let ir = content_types_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // Check all content type classes
        assert!(types.contains("public struct TextContent"));
        assert!(types.contains("public let body: String"));
        assert!(types.contains("public let wordCount: Int"));

        assert!(types.contains("public struct ImageContent"));
        assert!(types.contains("public let width: Int"));
        assert!(types.contains("public let height: Int"));

        assert!(types.contains("public struct VideoContent"));
        assert!(types.contains("public let durationSeconds: Int"));

        assert!(types.contains("public struct CodeBlock"));
        assert!(types.contains("public let lineCount: Int"));
    }

    #[test]
    fn test_function_with_union_param() {
        let ir = content_types_ir();
        let files = generate_swift(&ir).unwrap();
        let client = files.get("baml_client/BamlClient.swift").unwrap();

        // Check function with union parameter type
        assert!(client.contains("func analyzeContent"));
    }
}

// ============================================================================
// E-commerce Tests
// ============================================================================

mod ecommerce_tests {
    use super::*;

    #[test]
    fn test_money_value_object() {
        let ir = ecommerce_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        assert!(types.contains("public struct Money"));
        assert!(types.contains("public let amount: Double"));
        assert!(types.contains("public let currency: String"));
    }

    #[test]
    fn test_nested_class_references() {
        let ir = ecommerce_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // ProductVariant has Money
        assert!(types.contains("public let price: Money"));

        // Product has list of ProductVariant
        assert!(types.contains("public let variants: [ProductVariant]"));

        // Product has Money
        assert!(types.contains("public let basePrice: Money"));
    }

    #[test]
    fn test_order_status_enum() {
        let ir = ecommerce_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        assert!(types.contains("public enum OrderStatus"));
        assert!(types.contains("case pending"));
        assert!(types.contains("case processing"));
        assert!(types.contains("case shipped"));
        assert!(types.contains("case delivered"));
        assert!(types.contains("case cancelled"));
        assert!(types.contains("case refunded"));
    }

    #[test]
    fn test_payment_method_enum() {
        let ir = ecommerce_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        assert!(types.contains("public enum PaymentMethod"));
        assert!(types.contains("case creditCard"));
        assert!(types.contains("case debitCard"));
        assert!(types.contains("case paypal"));
        assert!(types.contains("case applePay"));
        assert!(types.contains("case googlePay"));
        assert!(types.contains("case bankTransfer"));
    }

    #[test]
    fn test_shipping_address_optionals() {
        let ir = ecommerce_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        assert!(types.contains("public struct ShippingAddress"));
        assert!(types.contains("public let recipientName: String"));
        assert!(types.contains("public let streetLine1: String"));
        assert!(types.contains("public let streetLine2: String?"));
        assert!(types.contains("public let state: String?"));
        assert!(types.contains("public let phone: String?"));
    }

    #[test]
    fn test_map_type_in_product_variant() {
        let ir = ecommerce_ir();
        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        assert!(types.contains("public let attributes: [String: String]"));
    }

    #[test]
    fn test_calculate_shipping_function() {
        let ir = ecommerce_ir();
        let files = generate_swift(&ir).unwrap();
        let client = files.get("baml_client/BamlClient.swift").unwrap();

        assert!(client.contains("func calculateShipping"));
        assert!(client.contains("destination: ShippingAddress"));
        assert!(client.contains("-> Money"));
    }
}

// ============================================================================
// Streaming Types Tests
// ============================================================================

mod streaming_tests {
    use super::*;

    #[test]
    fn test_streaming_types_generated() {
        let ir = sentiment_ir();
        let config = GeneratorConfig::default().with_streaming(true);
        let generator = SwiftGenerator::new(config);
        let files = generator.generate(&ir).unwrap();

        // Check StreamTypes.swift is generated
        let stream_types = files.get("baml_client/StreamTypes.swift");
        assert!(stream_types.is_some(), "StreamTypes.swift should be generated when streaming is enabled");

        let stream_types = stream_types.unwrap();

        // Check partial struct is generated
        assert!(stream_types.contains("SentimentResultPartial"));
    }

    #[test]
    fn test_streaming_disabled() {
        let ir = sentiment_ir();
        let config = GeneratorConfig::default().with_streaming(false);
        let generator = SwiftGenerator::new(config);
        let files = generator.generate(&ir).unwrap();

        // Check StreamTypes.swift is NOT generated
        let stream_types = files.get("baml_client/StreamTypes.swift");
        assert!(stream_types.is_none(), "StreamTypes.swift should NOT be generated when streaming is disabled");
    }
}

// ============================================================================
// Edge Cases Tests
// ============================================================================

mod edge_cases {
    use super::*;

    #[test]
    fn test_reserved_keyword_field() {
        let ir = BamlIR {
            classes: vec![ClassDef {
                name: "KeywordTest".to_string(),
                docstring: None,
                fields: vec![
                    FieldDef {
                        name: "class".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    },
                    FieldDef {
                        name: "return".to_string(),
                        field_type: FieldType::Int,
                        docstring: None,
                    },
                    FieldDef {
                        name: "self".to_string(),
                        field_type: FieldType::Bool,
                        docstring: None,
                    },
                ],
                has_dynamic_fields: false,
            }],
            ..Default::default()
        };

        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // Check keywords are escaped with backticks
        assert!(types.contains("public let `class`: String"));
        assert!(types.contains("public let `return`: Int"));
        assert!(types.contains("public let `self`: Bool"));
    }

    #[test]
    fn test_deeply_nested_optional() {
        let ir = BamlIR {
            classes: vec![ClassDef {
                name: "NestedOptional".to_string(),
                docstring: None,
                fields: vec![FieldDef {
                    name: "value".to_string(),
                    field_type: FieldType::Optional(Box::new(FieldType::List(Box::new(
                        FieldType::Optional(Box::new(FieldType::String)),
                    )))),
                    docstring: None,
                }],
                has_dynamic_fields: false,
            }],
            ..Default::default()
        };

        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // Check nested optional array
        assert!(types.contains("public let value: [String?]?"));
    }

    #[test]
    fn test_map_with_complex_value() {
        let ir = BamlIR {
            classes: vec![
                ClassDef {
                    name: "Item".to_string(),
                    docstring: None,
                    fields: vec![FieldDef {
                        name: "name".to_string(),
                        field_type: FieldType::String,
                        docstring: None,
                    }],
                    has_dynamic_fields: false,
                },
                ClassDef {
                    name: "Container".to_string(),
                    docstring: None,
                    fields: vec![FieldDef {
                        name: "items_by_id".to_string(),
                        field_type: FieldType::Map(
                            Box::new(FieldType::String),
                            Box::new(FieldType::List(Box::new(FieldType::Class(
                                "Item".to_string(),
                            )))),
                        ),
                        docstring: None,
                    }],
                    has_dynamic_fields: false,
                },
            ],
            ..Default::default()
        };

        let files = generate_swift(&ir).unwrap();
        let types = files.get("baml_client/Types.swift").unwrap();

        // Check map with array value type
        assert!(types.contains("public let itemsById: [String: [Item]]"));
    }

    #[test]
    fn test_empty_ir() {
        let ir = BamlIR::default();
        let files = generate_swift(&ir).unwrap();

        // Should still generate files even if empty
        assert!(files.get("baml_client/Types.swift").is_some());
        assert!(files.get("baml_client/BamlClient.swift").is_some());
        assert!(files.get("baml_client/Globals.swift").is_some());

        // But no Unions.swift since there are no unions
        assert!(files.get("baml_client/Unions.swift").is_none());
    }

    #[test]
    fn test_custom_output_dir() {
        let ir = sentiment_ir();
        let config = GeneratorConfig::default().with_output_dir("CustomClient");
        let generator = SwiftGenerator::new(config);
        let files = generator.generate(&ir).unwrap();

        assert!(files.get("CustomClient/Types.swift").is_some());
        assert!(files.get("CustomClient/BamlClient.swift").is_some());
        assert!(files.get("CustomClient/Globals.swift").is_some());
    }
}
