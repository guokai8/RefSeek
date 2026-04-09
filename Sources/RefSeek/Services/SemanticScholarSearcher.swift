import Foundation

/// Semantic Scholar search — free API, no key required
/// Docs: https://api.semanticscholar.org/
enum SemanticScholarSearcher {

    struct SearchResponse: Decodable {
        let total: Int?
        let data: [Paper]?
    }

    struct Paper: Decodable {
        let paperId: String?
        let externalIds: ExternalIds?
        let title: String?
        let authors: [Author]?
        let venue: String?
        let year: Int?
        let abstract: String?
        let citationCount: Int?
    }

    struct ExternalIds: Decodable {
        let DOI: String?
        let PubMed: String?
    }

    struct Author: Decodable {
        let name: String?
    }

    // MARK: - Search

    static func search(query: String, maxResults: Int = 50) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://api.semanticscholar.org/graph/v1/paper/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(min(maxResults, AppConstants.maxResultsSemanticScholar))),
            URLQueryItem(name: "fields", value: "title,authors,venue,year,abstract,externalIds,citationCount"),
        ]

        guard let url = components.url else {
            throw RefSeekError.invalidInput("Invalid Semantic Scholar query")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("RefSeek/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                throw RefSeekError.networkError("Semantic Scholar rate limit reached. Try again in a few seconds.")
            }
            throw RefSeekError.networkError("Semantic Scholar returned non-200 status")
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard let papers = decoded.data else { return [] }

        return papers.compactMap { paper in
            guard let title = paper.title, !title.isEmpty else { return nil }
            let doi = paper.externalIds?.DOI ?? ""
            let pmid = paper.externalIds?.PubMed
            let authors = paper.authors?.compactMap { $0.name } ?? []

            return SearchResult(
                doi: doi,
                title: title,
                authors: authors,
                journal: paper.venue,
                year: paper.year,
                abstract: paper.abstract,
                pmid: pmid,
                citationCount: paper.citationCount
            )
        }
    }
}
