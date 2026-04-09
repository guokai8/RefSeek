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
    case journalAsc = "Journal A→Z"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .relevance: return "sparkle.magnifyingglass"
        case .yearDesc: return "calendar.badge.minus"
        case .yearAsc: return "calendar.badge.plus"
        case .citationsDesc: return "quote.bubble"
        case .journalAsc: return "book"
        }
    }
}
