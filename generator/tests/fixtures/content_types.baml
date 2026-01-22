// Content with union types example

class TextContent {
    body string
    word_count int
    language string?
}

class ImageContent {
    url string
    alt_text string?
    width int
    height int
}

class VideoContent {
    url string
    duration_seconds int
    thumbnail_url string?
}

class CodeBlock {
    code string
    language string
    line_count int
}

// Union type - can be any of the content types
class ContentItem {
    id string
    title string
    // Union field - represented as Swift enum with associated values
    content TextContent | ImageContent | VideoContent | CodeBlock
    created_at string
    is_published bool
}

class ContentFeed {
    items ContentItem[]
    total_count int
    has_more bool
}

function AnalyzeContent(content: TextContent | ImageContent) -> string {
    client default
    prompt #"
        Analyze this content
    "#
}

function GetContentFeed(page: int, limit: int) -> ContentFeed {
    client default
    prompt #"
        Get content feed page {{ page }} with limit {{ limit }}
    "#
}
