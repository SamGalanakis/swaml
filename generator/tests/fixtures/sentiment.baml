// Sentiment analysis example

enum Sentiment {
    HAPPY
    SAD
    NEUTRAL
    ANGRY
    @@alias("Very Excited")
    EXCITED
}

class SentimentResult {
    sentiment Sentiment
    confidence float
    explanation string?
}

function ClassifySentiment(text: string) -> SentimentResult {
    client default
    prompt #"
        Analyze the sentiment of the following text:
        {{ text }}

        Return the sentiment classification.
    "#
}
