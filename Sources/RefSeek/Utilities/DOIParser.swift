import Foundation

enum DOIParser {
    /// Regex pattern for DOI: 10.XXXX/...
    private static let doiPattern = #"(10\.\d{4,9}/[^\s]+)"#

    /// Check if the input string is a valid DOI
    static func isDOI(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return extractDOI(from: trimmed) != nil
    }

    /// Extract a DOI from a string (handles URLs like https://doi.org/10.xxx/yyy)
    static func extractDOI(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try direct DOI pattern
        if let range = trimmed.range(of: doiPattern, options: .regularExpression) {
            var doi = String(trimmed[range])
            // Remove trailing punctuation that might have been captured
            while doi.last == "." || doi.last == "," || doi.last == ";" {
                doi.removeLast()
            }
            return doi
        }

        return nil
    }

    /// Normalize a DOI (lowercase, trim whitespace)
    static func normalize(_ doi: String) -> String {
        return doi.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Build a DOI URL
    static func url(for doi: String) -> URL? {
        return URL(string: "https://doi.org/\(doi)")
    }
}
