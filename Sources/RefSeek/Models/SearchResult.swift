import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let doi: String
    let title: String
    let authors: [String]
    let journal: String?
    let year: Int?
    let abstract: String?
    var pmid: String? = nil
    var citationCount: Int? = nil
    var isOpenAccess: Bool? = nil
    var journalImpactFactor: Double? = nil
    var ifSource: String? = nil         // "JCR" or "OpenAlex"
    var jcrQuartile: String? = nil      // "Q1", "Q2", "Q3", "Q4"
    var downloadStatus: DownloadStatus = .idle

    enum DownloadStatus: Equatable {
        case idle
        case downloading(Double)
        case completed
        case failed(String)
    }
}

/// Sort options for search results
enum SearchSortOption: String, CaseIterable, Identifiable {
    case relevance = "Relevance"
    case yearDesc = "Year ↓ (newest)"
    case yearAsc = "Year ↑ (oldest)"
    case citationsDesc = "Citations ↓"
    case impactFactorDesc = "Impact Factor ↓"
    case journalAsc = "Journal A→Z"
    case authorAsc = "Author A→Z"
    case titleAsc = "Title A→Z"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .relevance: return "sparkle.magnifyingglass"
        case .yearDesc: return "calendar.badge.minus"
        case .yearAsc: return "calendar.badge.plus"
        case .citationsDesc: return "quote.bubble"
        case .impactFactorDesc: return "chart.bar.fill"
        case .journalAsc: return "book"
        case .authorAsc: return "person"
        case .titleAsc: return "textformat.abc"
        }
    }
}
