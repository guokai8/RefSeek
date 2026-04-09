import Foundation
import AppKit

enum AppConstants {
    static let appName = "RefSeek"

    // MARK: - API Endpoints
    static let crossRefBaseURL = "https://api.crossref.org/works"
    static let unpaywallBaseURL = "https://api.unpaywall.org/v2"
    static let pmcIdConverterURL = "https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/"
    static let pubmedSearchURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
    static let pubmedSummaryURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"

    // MARK: - Sci-Hub Mirrors (updated periodically)
    static let defaultScihubMirrors = [
        "https://sci-hub.st",
        "https://sci-hub.ru",
        "https://sci-hub.mksa.top",
        "https://sci-hub.se",
        "https://sci-hub.ren"
    ]

    // MARK: - User Defaults Keys
    static let downloadFolderKey = "downloadFolder"
    static let unpaywallEmailKey = "unpaywallEmail"
    static let scihubMirrorsKey = "scihubMirrors"
    static let maxConcurrentDownloadsKey = "maxConcurrentDownloads"
    static let searchEngineKey = "searchEngine"
    static let maxSearchResultsKey = "maxSearchResults"
    static let hotkeyCharacterKey = "hotkeyCharacter"
    static let hotkeyModifiersKey = "hotkeyModifiers"

    // MARK: - Hotkey Defaults
    static let defaultHotkeyCharacter = "r"
    /// Stored as raw UInt value of NSEvent.ModifierFlags
    static let defaultHotkeyModifiers: UInt = NSEvent.ModifierFlags([.command, .shift]).rawValue

    // MARK: - Defaults
    static let defaultMaxConcurrentDownloads = 3
    static let defaultMaxSearchResults = 50

    // MARK: - Per-API Result Limits
    /// Each API has its own max; we clamp the user setting to these
    static let maxResultsPubMed = 200       // PubMed retmax up to 10k, 200 is practical
    static let maxResultsCrossRef = 200     // CrossRef rows up to 1000
    static let maxResultsSemanticScholar = 100  // S2 hard limit
    static let maxResultsOpenAlex = 200     // OpenAlex per_page up to 200
    static let defaultDownloadFolder: String = {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        return downloads.appendingPathComponent("RefSeek").path
    }()

    // MARK: - PDF
    static let pdfMagicBytes: [UInt8] = [0x25, 0x50, 0x44, 0x46] // %PDF
}

/// Search engine options
enum SearchEngine: String, CaseIterable, Identifiable {
    case pubmed = "PubMed"
    case crossref = "CrossRef"
    case semanticScholar = "Semantic Scholar"
    case openAlex = "OpenAlex"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .pubmed: return "NCBI PubMed — biomedical literature"
        case .crossref: return "CrossRef — broad academic coverage"
        case .semanticScholar: return "Semantic Scholar — AI-powered, CS/bio/med"
        case .openAlex: return "OpenAlex — 250M+ works, fully open"
        }
    }

    var icon: String {
        switch self {
        case .pubmed: return "cross.case"
        case .crossref: return "book.pages"
        case .semanticScholar: return "brain.head.profile"
        case .openAlex: return "globe"
        }
    }
}
