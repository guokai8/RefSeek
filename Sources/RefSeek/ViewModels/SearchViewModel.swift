import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching = false
    @Published var isDownloadingAll = false
    @Published var errorMessage: String?
    @Published var parsedQuery: SearchQueryParser.ParsedQuery?
    @Published var searchHistory: [String] = []
    @Published var searchEngine: SearchEngine
    @Published var useLLMExpand = false
    @Published var llmAvailable = false
    @Published var expandedQuery: String?
    @Published var selectedResultIDs: Set<UUID> = []
    @Published var sortOption: SearchSortOption = .relevance

    private let fetcher = PaperFetcher()
    private static let historyKey = "searchHistory"
    private static let maxHistory = 20

    /// User-configurable max results (read from UserDefaults)
    var maxResults: Int {
        let stored = UserDefaults.standard.integer(forKey: AppConstants.maxSearchResultsKey)
        return stored > 0 ? stored : AppConstants.defaultMaxSearchResults
    }

    init() {
        searchHistory = UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
        let raw = UserDefaults.standard.string(forKey: AppConstants.searchEngineKey) ?? SearchEngine.pubmed.rawValue
        searchEngine = SearchEngine(rawValue: raw) ?? .pubmed
        // Check Ollama availability in background
        Task { llmAvailable = await OllamaHelper.isAvailable() }
    }

    /// Persist engine choice
    func setEngine(_ engine: SearchEngine) {
        searchEngine = engine
        UserDefaults.standard.set(engine.rawValue, forKey: AppConstants.searchEngineKey)
    }

    /// Whether the current query uses structured field syntax
    var isStructuredQuery: Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let fieldPatterns = ["author:", "title:", "journal:", "year:", "[au]", "[ti]", "[ta]", "[dp]"]
        return fieldPatterns.contains(where: { q.localizedCaseInsensitiveContains($0) })
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        results = []
        parsedQuery = nil
        expandedQuery = nil
        selectedResultIDs = []

        // Optionally expand query with LLM
        var searchQuery = trimmed
        if useLLMExpand && llmAvailable && !DOIParser.isDOI(trimmed) && !isStructuredQuery {
            if let expanded = await OllamaHelper.expandQuery(trimmed) {
                expandedQuery = expanded
                searchQuery = expanded
            }
        }

        do {
            if DOIParser.isDOI(trimmed) {
                // Direct DOI → fetch metadata (always via CrossRef)
                let doi = DOIParser.extractDOI(from: trimmed) ?? trimmed
                if let result = try await DOIResolver.metadata(for: doi) {
                    results = [result]
                } else {
                    results = [SearchResult(doi: doi, title: doi, authors: [], journal: nil, year: nil, abstract: nil)]
                }
            } else if isStructuredQuery {
                // Structured search with field qualifiers
                let parsed = SearchQueryParser.parse(trimmed)
                parsedQuery = parsed
                results = try await searchStructured(parsed)
                if results.isEmpty {
                    errorMessage = "No results found for structured query"
                }
            } else {
                // Keyword / title search → use selected engine
                results = try await searchKeyword(searchQuery)
                if results.isEmpty {
                    errorMessage = "No results found for '\(trimmed)'"
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        // Save to history
        addToHistory(trimmed)
        isSearching = false
    }

    /// Route keyword search to selected engine
    private func searchKeyword(_ query: String) async throws -> [SearchResult] {
        let limit = maxResults
        switch searchEngine {
        case .pubmed:
            return try await PubMedSearcher.search(query: query, maxResults: limit)
        case .crossref:
            return try await DOIResolver.resolve(title: query, maxResults: limit)
        case .semanticScholar:
            return try await SemanticScholarSearcher.search(query: query, maxResults: limit)
        case .openAlex:
            return try await OpenAlexSearcher.search(query: query, maxResults: limit)
        }
    }

    /// Route structured search to selected engine
    private func searchStructured(_ parsed: SearchQueryParser.ParsedQuery) async throws -> [SearchResult] {
        let limit = maxResults
        switch searchEngine {
        case .pubmed:
            return try await PubMedSearcher.structuredSearch(query: parsed, maxResults: limit)
        case .crossref:
            return try await DOIResolver.structuredSearch(query: parsed, maxResults: limit)
        case .semanticScholar:
            return try await SemanticScholarSearcher.search(query: parsed.description, maxResults: limit)
        case .openAlex:
            return try await OpenAlexSearcher.search(query: parsed.description, maxResults: limit)
        }
    }

    private func addToHistory(_ query: String) {
        searchHistory.removeAll { $0.lowercased() == query.lowercased() }
        searchHistory.insert(query, at: 0)
        if searchHistory.count > Self.maxHistory {
            searchHistory = Array(searchHistory.prefix(Self.maxHistory))
        }
        UserDefaults.standard.set(searchHistory, forKey: Self.historyKey)
    }

    func clearHistory() {
        searchHistory = []
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
    }

    // MARK: - Selection Helpers

    /// Results after applying the current sort
    var sortedResults: [SearchResult] {
        switch sortOption {
        case .relevance:
            return results
        case .yearDesc:
            return results.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        case .yearAsc:
            return results.sorted { ($0.year ?? 9999) < ($1.year ?? 9999) }
        case .citationsDesc:
            return results.sorted { ($0.citationCount ?? -1) > ($1.citationCount ?? -1) }
        case .journalAsc:
            return results.sorted {
                ($0.journal ?? "zzz").localizedCaseInsensitiveCompare($1.journal ?? "zzz") == .orderedAscending
            }
        }
    }

    var allSelected: Bool {
        !results.isEmpty && selectedResultIDs.count == results.count
    }

    func toggleSelectAll() {
        if allSelected {
            selectedResultIDs.removeAll()
        } else {
            selectedResultIDs = Set(results.map { $0.id })
        }
    }

    /// Download all results (or selected only) concurrently
    func downloadMultiple(ids: Set<UUID>? = nil, store: PaperStore) async {
        let targets: [SearchResult]
        if let ids = ids, !ids.isEmpty {
            targets = results.filter { ids.contains($0.id) }
        } else {
            targets = results
        }

        let downloadable = targets.filter { !$0.doi.isEmpty && $0.downloadStatus != .completed }
        guard !downloadable.isEmpty else { return }

        isDownloadingAll = true
        let maxConcurrent = UserDefaults.standard.integer(forKey: AppConstants.maxConcurrentDownloadsKey)
        let concurrency = maxConcurrent > 0 ? maxConcurrent : AppConstants.defaultMaxConcurrentDownloads

        await withTaskGroup(of: Void.self) { group in
            var running = 0
            var queue = downloadable.makeIterator()

            // Seed initial batch
            for _ in 0..<concurrency {
                guard let result = queue.next() else { break }
                running += 1
                group.addTask { [weak self] in
                    await self?.download(result: result, store: store)
                }
            }

            // As each finishes, start the next
            for await _ in group {
                running -= 1
                if let result = queue.next() {
                    running += 1
                    group.addTask { [weak self] in
                        await self?.download(result: result, store: store)
                    }
                }
            }
        }

        isDownloadingAll = false
    }

    func download(result: SearchResult, store: PaperStore) async {
        guard let index = results.firstIndex(where: { $0.id == result.id }) else { return }

        if result.doi.isEmpty {
            results[index].downloadStatus = .failed("No DOI available — cannot download PDF")
            return
        }

        results[index].downloadStatus = .downloading(0)

        do {
            _ = try await fetcher.fetchAndSave(
                doi: result.doi,
                store: store,
                progressHandler: { [weak self] progress in
                    guard let self else { return }
                    if let idx = self.results.firstIndex(where: { $0.id == result.id }) {
                        self.results[idx].downloadStatus = .downloading(progress)
                    }
                }
            )
            if let idx = results.firstIndex(where: { $0.id == result.id }) {
                results[idx].downloadStatus = .completed
            }
        } catch {
            if let idx = results.firstIndex(where: { $0.id == result.id }) {
                results[idx].downloadStatus = .failed(error.localizedDescription)
            }
        }
    }
}
