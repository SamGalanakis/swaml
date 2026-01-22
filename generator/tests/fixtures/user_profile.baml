// User profile extraction example

enum AccountStatus {
    ACTIVE
    INACTIVE
    SUSPENDED
    PENDING_VERIFICATION
}

class Address {
    street_address string
    city string
    state string?
    postal_code string
    country string
}

class SocialMedia {
    platform string
    handle string
    url string?
    followers int?
}

class UserProfile {
    user_id string
    first_name string
    last_name string
    email string
    age int?
    is_verified bool
    account_status AccountStatus
    addresses Address[]
    social_links SocialMedia[]
    tags string[]
    metadata map<string, string>
}

function ExtractUserProfile(raw_text: string, include_social: bool) -> UserProfile {
    client default
    prompt #"
        Extract the user profile from the following text:
        {{ raw_text }}

        Include social media: {{ include_social }}
    "#
}

function GetUsersByStatus(status: AccountStatus) -> UserProfile[] {
    client default
    prompt #"
        Get all users with status: {{ status }}
    "#
}
