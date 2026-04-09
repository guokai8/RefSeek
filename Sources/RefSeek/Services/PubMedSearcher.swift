import Foundation

/// PubMed search using NCBI E-utilities (ESearch + ESummary)
enum PubMedSearcher {

    // MARK: - Response Models

    struct ESearchResult: Decodable {
        let esearchresult: ESearchData
    }

    struct ESearchData: Decodable {
        let idlist: [String]
        let count: String?
    }

    struct ESummaryResult: Decodable {
        let result: ESummaryData
    }

    struct ESummaryData: Decodable {
        let uids: [String]?

        // Dynamic article data keyed by PMID
        private var articles: [String: ArticleSummary] = [:]

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            var articles: [String: ArticleSummary] = [:]
            var uids: [String]? = nil

            for key in container.allKeys {
                if key.stringValue == "uids" {
                    uids = try? container.decode([String].self, forKey: key)
                } else {
                    if let article = try? container.decode(ArticleSummary.self, forKey: key) {
                        articles[key.stringValue] = article
                    }
                }
            }
            self.uids = uids
            self.articles = articles
        }

        func article(for uid: String) -> ArticleSummary? {
            articles[uid]
        }
    }

    struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    }

    struct ArticleSummary: Decodable {
        let uid: String?
        let title: String?
        let sortfirstauthor: String?
        let authors: [AuthorInfo]?
        let source: String?
        let pubdate: String?
        let elocationid: String?
        let articleids: [ArticleId]?

        var doi: String? {
            // Try elocationid first (format: "doi: 10.xxxx/xxxxx")
            if let eid = elocationid, eid.lowercased().hasPrefix("doi:") {
                let cleaned = eid.replacingOccurrences(of: "doi:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty { return cleaned }
            }
            // Fall back to articleids
            return articleids?.first(where: { $0.idtype == "doi" })?.value
        }

        var year: Int? {
            guard let pubdate = pubdate else { return nil }
            let components = pubdate.split(separator: " ")
            if let yearStr = components.first, let y = Int(yearStr) {
                return y
            }
            return nil
        }

        var authorNames: [String] {
            authors?.compactMap { $0.name } ?? []
        }
    }

    struct AuthorInfo: Decodable {
        let name: String?
        let authtype: String?
    }

    struct ArticleId: Decodable {
        let idtype: String?
        let value: String?
    }

    // MARK: - Search

    /// Search PubMed with a query string and return SearchResults
    static func search(query: String, maxResults: Int = 50) async throws -> [SearchResult] {
        let pmids = try await esearch(query: query, maxResults: maxResults)
        guard !pmids.isEmpty else { return [] }
        return try await esummary(pmids: pmids)
    }

    /// Build a PubMed query from structured fields
    static func structuredSearch(query: SearchQueryParser.ParsedQuery, maxResults: Int = 50) async throws -> [SearchResult] {
        let pubmedQuery = buildPubMedQuery(from: query)
        return try await search(query: pubmedQuery, maxResults: maxResults)
    }

    // MARK: - E-utilities

    /// ESearch: query → list of PMIDs
    private static func esearch(query: String, maxResults: Int) async throws -> [String] {
        var components = URLComponents(string: AppConstants.pubmedSearchURL)!
        components.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "retmax", value: String(maxResults)),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "sort", value: "relevance"),
        ]

        guard let url = components.url else {
            throw RefSeekError.invalidInput("Invalid PubMed query")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RefSeekError.networkError("PubMed ESearch returned non-200 status")
        }

        let result = try JSONDecoder().decode(ESearchResult.self, from: data)
        return result.esearchresult.idlist
    }

    /// ESummary: PMIDs → article metadata
    private static func esummary(pmids: [String]) async throws -> [SearchResult] {
        var components = URLComponents(string: AppConstants.pubmedSummaryURL)!
        components.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: pmids.joined(separator: ",")),
            URLQueryItem(name: "retmode", value: "json"),
        ]

        guard let url = components.url else {
            throw RefSeekError.invalidInput("Invalid PubMed summary request")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RefSeekError.networkError("PubMed ESummary returned non-200 status")
        }

        let result = try JSONDecoder().decode(ESummaryResult.self, from: data)

        // Preserve order from pmids
        return pmids.compactMap { pmid in
            guard let article = result.result.article(for: pmid) else { return nil }
            guard let title = article.title, !title.isEmpty else { return nil }

            let doi = article.doi ?? ""
            return SearchResult(
                doi: doi,
                title: title,
                authors: article.authorNames,
                journal: article.source,
                year: article.year,
                abstract: nil,
                pmid: pmid
            )
        }
    }

    // MARK: - Query Builder

    /// Convert structured ParsedQuery to PubMed query syntax
    private static func buildPubMedQuery(from parsed: SearchQueryParser.ParsedQuery) -> String {
        var parts: [String] = []

        if !parsed.generalTerms.isEmpty {
            parts.append(parsed.generalTerms.joined(separator: " "))
        }
        for author in parsed.authorTerms {
            parts.append("\(author)[Author]")
        }
        for title in parsed.titleTerms {
            parts.append("\(title)[Title]")
        }
        for journal in parsed.journalTerms {
            parts.append("\(journal)[Journal]")
        }
        if let yearFrom = parsed.yearFrom, let yearTo = parsed.yearTo, yearFrom != yearTo {
            parts.append("\(yearFrom):\(yearTo)[Date - Publication]")
        } else if let yearFrom = parsed.yearFrom {
            parts.append("\(yearFrom)[Date - Publication]")
        }

        return parts.joined(separator: " AND ")
    }
}
