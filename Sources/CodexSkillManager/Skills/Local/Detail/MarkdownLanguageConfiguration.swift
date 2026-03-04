import LanguageSupport

extension LanguageConfiguration {

    /// A minimal language configuration for Markdown syntax highlighting.
    ///
    /// Highlights:
    /// - Inline code (backtick strings)
    /// - Fenced code blocks (triple-backtick strings)
    /// - HTML comments (`<!-- ... -->`) as nested comments
    static func markdownLanguage() -> LanguageConfiguration {
        LanguageConfiguration(
            name: "Markdown",
            supportsSquareBrackets: false,
            supportsCurlyBrackets: false,
            stringRegex: /`{3}[\s\S]*?`{3}|`[^`\n]+`/,
            characterRegex: nil,
            numberRegex: nil,
            singleLineComment: nil,
            nestedComment: (open: "<!--", close: "-->"),
            identifierRegex: nil,
            operatorRegex: nil,
            reservedIdentifiers: [],
            reservedOperators: []
        )
    }
}
