import Foundation

/// Parses NCBI-style search queries into structured CrossRef API parameters.
///
/// Supported syntax:
///   - `author:Smith` or `Smith[au]` — author field
///   - `title:CRISPR` or `CRISPR[ti]` — title field
///   - `journal:Nature` or `Nature[ta]` — journal/container-title
///   - `year:2020` or `2020[dp]` — publication year (exact or range like 2019-2022)
///   - Free text (no qualifier) — general bibliographic query
///
/// Multiple terms are combined. Example:
///   `CRISPR author:Doudna year:2020`
struct SearchQueryParser {

    struct ParsedQuery {
        var generalTerms: [String] = []
        var titleTerms: [String] = []
        var authorTerms: [String] = []
        var journalTerms: [String] = []
        var yearFrom: String?
        var yearTo: String?

        var isEmpty: Bool {
            generalTerms.isEmpty && titleTerms.isEmpty &&
            authorTerms.isEmpty && journalTerms.isEmpty &&
            yearFrom == nil
        }

        /// Build CrossRef API query parameters
        func crossRefQueryItems() -> [URLQueryItem] {
            var items: [URLQueryItem] = []

            // General bibliographic query
            if !generalTerms.isEmpty {
                items.append(URLQueryItem(name: "query.bibliographic", value: generalTerms.joined(separator: " ")))
            }
            // Title-specific
            if !titleTerms.isEmpty {
                items.append(URLQueryItem(name: "query.title", value: titleTerms.joined(separator: " ")))
            }
            // Author-specific
            if !authorTerms.isEmpty {
                items.append(URLQueryItem(name: "query.author", value: authorTerms.joined(separator: " ")))
            }
            // Journal / container-title
            if !journalTerms.isEmpty {
                items.append(URLQueryItem(name: "query.container-title", value: journalTerms.joined(separator: " ")))
            }
            // Year filter
            var filters: [String] = []
            if let from = yearFrom {
                filters.append("from-pub-date:\(from)")
            }
            if let to = yearTo {
                filters.append("until-pub-date:\(to)")
            } else if yearFrom != nil {
                // If only one year, use it as both from and to
                filters.append("until-pub-date:\(yearFrom!)")
            }
            if !filters.isEmpty {
                items.append(URLQueryItem(name: "filter", value: filters.joined(separator: ",")))
            }

            return items
        }

        /// Human-readable description of the parsed query
        var description: String {
            var parts: [String] = []
            if !generalTerms.isEmpty { parts.append("text: \(generalTerms.joined(separator: " "))") }
            if !titleTerms.isEmpty { parts.append("title: \(titleTerms.joined(separator: " "))") }
            if !authorTerms.isEmpty { parts.append("author: \(authorTerms.joined(separator: " "))") }
            if !journalTerms.isEmpty { parts.append("journal: \(journalTerms.joined(separator: " "))") }
            if let from = yearFrom, let to = yearTo, from != to {
                parts.append("year: \(from)-\(to)")
            } else if let from = yearFrom {
                parts.append("year: \(from)")
            }
            return parts.joined(separator: " · ")
        }
    }

    /// Parse a search string into a structured query
    static func parse(_ input: String) -> ParsedQuery {
        var result = ParsedQuery()
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return result }

        // First, handle NCBI bracket notation: term[qualifier]
        // Then handle prefix notation: qualifier:term
        var remaining = trimmed

        // Pattern: "term"[qualifier] or term[qualifier]
        let bracketPattern = #"(?:"([^"]+)"|(\S+))\s*\[(au|ti|ta|dp)\]"#
        if let regex = try? NSRegularExpression(pattern: bracketPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: remaining, range: NSRange(remaining.startIndex..., in: remaining))
            // Process in reverse to safely remove ranges
            for match in matches.reversed() {
                let quotedRange = Range(match.range(at: 1), in: remaining)
                let unquotedRange = Range(match.range(at: 2), in: remaining)
                let qualRange = Range(match.range(at: 3), in: remaining)!
                let fullRange = Range(match.range, in: remaining)!

                let term = quotedRange.map { String(remaining[$0]) } ?? unquotedRange.map { String(remaining[$0]) } ?? ""
                let qualifier = String(remaining[qualRange]).lowercased()

                addTerm(term, qualifier: qualifier, to: &result)
                remaining.removeSubrange(fullRange)
            }
        }

        // Pattern: qualifier:term or qualifier:"multi word term"
        let prefixPattern = #"(author|title|journal|year|au|ti|ta|dp)\s*:\s*(?:"([^"]+)"|(\S+))"#
        if let regex = try? NSRegularExpression(pattern: prefixPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: remaining, range: NSRange(remaining.startIndex..., in: remaining))
            for match in matches.reversed() {
                let qualRange = Range(match.range(at: 1), in: remaining)!
                let quotedRange = Range(match.range(at: 2), in: remaining)
                let unquotedRange = Range(match.range(at: 3), in: remaining)
                let fullRange = Range(match.range, in: remaining)!

                let qualifier = normalizeQualifier(String(remaining[qualRange]))
                let term = quotedRange.map { String(remaining[$0]) } ?? unquotedRange.map { String(remaining[$0]) } ?? ""

                addTerm(term, qualifier: qualifier, to: &result)
                remaining.removeSubrange(fullRange)
            }
        }

        // Anything left is general query (strip AND/OR connectors)
        let leftover = remaining
            .replacingOccurrences(of: "\\bAND\\b", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\bOR\\b", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !leftover.isEmpty {
            result.generalTerms.append(leftover)
        }

        // If no structured terms at all, treat everything as title search
        if result.titleTerms.isEmpty && result.authorTerms.isEmpty &&
           result.journalTerms.isEmpty && result.yearFrom == nil &&
           !result.generalTerms.isEmpty {
            // Keep as general terms — CrossRef will search bibliographically
        }

        return result
    }

    private static func normalizeQualifier(_ q: String) -> String {
        switch q.lowercased() {
        case "author", "au": return "au"
        case "title", "ti": return "ti"
        case "journal", "ta": return "ta"
        case "year", "dp": return "dp"
        default: return q.lowercased()
        }
    }

    private static func addTerm(_ term: String, qualifier: String, to result: inout ParsedQuery) {
        let cleaned = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        switch qualifier {
        case "au": result.authorTerms.append(cleaned)
        case "ti": result.titleTerms.append(cleaned)
        case "ta": result.journalTerms.append(cleaned)
        case "dp": parseYear(cleaned, into: &result)
        default: result.generalTerms.append(cleaned)
        }
    }

    private static func parseYear(_ value: String, into result: inout ParsedQuery) {
        // Handle range: 2019-2022
        if value.contains("-") {
            let parts = value.split(separator: "-").map(String.init)
            if parts.count == 2 {
                result.yearFrom = parts[0].trimmingCharacters(in: .whitespaces)
                result.yearTo = parts[1].trimmingCharacters(in: .whitespaces)
                return
            }
        }
        // Single year
        result.yearFrom = value
        result.yearTo = value
    }
}
