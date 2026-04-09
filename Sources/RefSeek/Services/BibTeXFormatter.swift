import Foundation

enum BibTeXFormatter {
    /// Generate BibTeX entry for a Paper
    static func format(_ paper: Paper) -> String {
        let key = generateKey(paper)
        var lines: [String] = []

        lines.append("@article{\(key),")
        lines.append("  title = {\(escapeTeX(paper.title))},")

        if !paper.authors.isEmpty {
            let authorStr = paper.authors.joined(separator: " and ")
            lines.append("  author = {\(escapeTeX(authorStr))},")
        }

        if let journal = paper.journal {
            lines.append("  journal = {\(escapeTeX(journal))},")
        }

        if let year = paper.year {
            lines.append("  year = {\(year)},")
        }

        lines.append("  doi = {\(paper.doi)},")

        // Remove trailing comma from last field
        if var last = lines.last {
            if last.hasSuffix(",") {
                last.removeLast()
                lines[lines.count - 1] = last
            }
        }

        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// Format multiple papers as a .bib file
    static func formatAll(_ papers: [Paper]) -> String {
        papers.map { format($0) }.joined(separator: "\n\n")
    }

    /// Generate a BibTeX citation key: FirstAuthorLastNameYear
    private static func generateKey(_ paper: Paper) -> String {
        var key = ""
        if let firstAuthor = paper.authors.first {
            let parts = firstAuthor.split(separator: " ")
            key += (parts.last.map(String.init) ?? "unknown").lowercased()
        } else {
            key += "unknown"
        }
        if let year = paper.year {
            key += String(year)
        }
        // Add first word of title for uniqueness
        let titleWord = paper.title
            .split(separator: " ")
            .first
            .map(String.init)?
            .lowercased()
            .filter { $0.isLetter } ?? ""
        key += titleWord

        return key
    }

    /// Escape special LaTeX characters
    private static func escapeTeX(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("&", "\\&"),
            ("%", "\\%"),
            ("$", "\\$"),
            ("#", "\\#"),
            ("_", "\\_"),
            ("{", "\\{"),
            ("}", "\\}")
        ]
        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }
}
