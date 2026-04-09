import Foundation

/// OpenAlex search — free API, no key required, 250M+ works
/// Docs: https://docs.openalex.org/
enum OpenAlexSearcher {

    struct SearchResponse: Decodable {
        let results: [Work]?
    }

    struct Work: Decodable {
        let id: String?
        let doi: String?
        let title: String?
        let authorships: [Authorship]?
        let primary_location: Location?
        let publication_year: Int?
        let cited_by_count: Int?

        enum CodingKeys: String, CodingKey {
            case id, doi, title, authorships, primary_location, publication_year, cited_by_count
        }
    }

    struct Authorship: Decodable {
        let author: AuthorInfo?
    }

    struct AuthorInfo: Decodable {
        let display_name: String?
    }

    struct Location: Decodable {
        let source: Source?
    }

    struct Source: Decodable {
        let display_name: String?
    }

    // MARK: - Search

    static func search(query: String, maxResults: Int = 50) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://api.openalex.org/works")!
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "per_page", value: String(min(maxResults, AppConstants.maxResultsOpenAlex))),
            URLQueryItem(name: "sort", value: "relevance_score:desc"),
            URLQueryItem(name: "select", value: "id,doi,title,authorships,primary_location,publication_year,cited_by_count"),
        ]

        guard let url = components.url else {
            throw RefSeekError.invalidInput("Invalid OpenAlex query")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("RefSeek/1.0 (mailto:refseek@example.com)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RefSeekError.networkError("OpenAlex returned non-200 status")
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard let works = decoded.results else { return [] }

        return works.compactMap { work in
            guard let title = work.title, !title.isEmpty else { return nil }

            // Clean DOI: OpenAlex returns full URL like "https://doi.org/10.xxxx"
            var doi = work.doi ?? ""
            if doi.hasPrefix("https://doi.org/") {
                doi = String(doi.dropFirst("https://doi.org/".count))
            }

            let authors = work.authorships?.compactMap { $0.author?.display_name } ?? []
            let journal = work.primary_location?.source?.display_name

            return SearchResult(
                doi: doi,
                title: title,
                authors: authors,
                journal: journal,
                year: work.publication_year,
                abstract: nil,
                citationCount: work.cited_by_count
            )
        }
    }
}
