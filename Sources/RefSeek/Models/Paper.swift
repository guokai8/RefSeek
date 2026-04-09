import Foundation

final class Paper: ObservableObject, Codable, Identifiable, Hashable {
    let id: UUID
    var doi: String
    var title: String
    var authors: [String]
    var journal: String?
    var year: Int?
    var abstract: String?
    var pdfPath: String?
    var source: String?
    @Published var notes: String = ""
    var dateAdded: Date = Date()
    var tagNames: [String] = []
    var category: String = ""
    var summary: String = ""

    init(
        id: UUID = UUID(),
        doi: String,
        title: String,
        authors: [String] = [],
        journal: String? = nil,
        year: Int? = nil,
        abstract: String? = nil,
        pdfPath: String? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.doi = doi
        self.title = title
        self.authors = authors
        self.journal = journal
        self.year = year
        self.abstract = abstract
        self.pdfPath = pdfPath
        self.source = source
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, doi, title, authors, journal, year, abstract, pdfPath, source, notes, dateAdded, tagNames, category, summary
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(doi, forKey: .doi)
        try container.encode(title, forKey: .title)
        try container.encode(authors, forKey: .authors)
        try container.encodeIfPresent(journal, forKey: .journal)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(abstract, forKey: .abstract)
        try container.encodeIfPresent(pdfPath, forKey: .pdfPath)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encode(notes, forKey: .notes)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(tagNames, forKey: .tagNames)
        try container.encode(category, forKey: .category)
        try container.encode(summary, forKey: .summary)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        doi = try container.decode(String.self, forKey: .doi)
        title = try container.decode(String.self, forKey: .title)
        authors = try container.decode([String].self, forKey: .authors)
        journal = try container.decodeIfPresent(String.self, forKey: .journal)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        abstract = try container.decodeIfPresent(String.self, forKey: .abstract)
        pdfPath = try container.decodeIfPresent(String.self, forKey: .pdfPath)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        tagNames = try container.decodeIfPresent([String].self, forKey: .tagNames) ?? []
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
    }

    // MARK: - Hashable
    static func == (lhs: Paper, rhs: Paper) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: - Computed
    var authorString: String {
        authors.joined(separator: ", ")
    }

    var citation: String {
        var parts: [String] = []
        if !authors.isEmpty {
            parts.append(authorString)
        }
        if let year = year {
            parts.append("(\(year))")
        }
        parts.append(title)
        if let journal = journal {
            parts.append(journal)
        }
        return parts.joined(separator: ". ") + "."
    }

    var hasPDF: Bool {
        guard let path = pdfPath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
}
