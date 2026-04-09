import Foundation

enum DOIResolver {
    struct CrossRefResponse: Decodable {
        let message: Message
        struct Message: Decodable {
            let items: [Item]?
        }
        struct Item: Decodable {
            let DOI: String
            let title: [String]?
            let author: [Author]?
            let containerTitle: [String]?
            let published: DateParts?
            let abstract: String?
            let isReferencedByCount: Int?

            enum CodingKeys: String, CodingKey {
                case DOI
                case title
                case author
                case containerTitle = "container-title"
                case published
                case abstract
                case isReferencedByCount = "is-referenced-by-count"
            }
        }
        struct Author: Decodable {
            let given: String?
            let family: String?
        }
        struct DateParts: Decodable {
            let dateParts: [[Int]]?
            enum CodingKeys: String, CodingKey {
                case dateParts = "date-parts"
            }
        }
    }

    /// Resolve a paper title to DOI + metadata via CrossRef
    static func resolve(title: String, maxResults: Int = 50) async throws -> [SearchResult] {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(AppConstants.crossRefBaseURL)?query=\(encoded)&rows=\(maxResults)") else {
            throw RefSeekError.invalidInput("Invalid search query")
        }

        var request = URLRequest(url: url)
        request.setValue("RefSeek/1.0 (mailto:refseek@example.com)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RefSeekError.networkError("CrossRef returned non-200 status")
        }

        let decoded = try JSONDecoder().decode(CrossRefResponse.self, from: data)
        guard let items = decoded.message.items else { return [] }

        return items.compactMap { item in
            guard let title = item.title?.first else { return nil }
            let authors = item.author?.compactMap { a -> String? in
                guard let family = a.family else { return nil }
                if let given = a.given {
                    return "\(given) \(family)"
                }
                return family
            } ?? []

            let year = item.published?.dateParts?.first?.first

            return SearchResult(
                doi: item.DOI,
                title: title,
                authors: authors,
                journal: item.containerTitle?.first,
                year: year,
                abstract: item.abstract,
                citationCount: item.isReferencedByCount
            )
        }
    }

    /// Structured search using NCBI-style query syntax
    static func structuredSearch(query: SearchQueryParser.ParsedQuery, maxResults: Int = 50) async throws -> [SearchResult] {
        var components = URLComponents(string: AppConstants.crossRefBaseURL)!
        var queryItems = query.crossRefQueryItems()
        queryItems.append(URLQueryItem(name: "rows", value: String(maxResults)))
        queryItems.append(URLQueryItem(name: "sort", value: "relevance"))
        queryItems.append(URLQueryItem(name: "order", value: "desc"))
        components.queryItems = queryItems

        guard let url = components.url else {
            throw RefSeekError.invalidInput("Invalid structured query")
        }

        var request = URLRequest(url: url)
        request.setValue("RefSeek/1.0 (mailto:refseek@example.com)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RefSeekError.networkError("CrossRef returned non-200 status")
        }

        let decoded = try JSONDecoder().decode(CrossRefResponse.self, from: data)
        guard let items = decoded.message.items else { return [] }

        return items.compactMap { item in
            guard let title = item.title?.first else { return nil }
            let authors = item.author?.compactMap { a -> String? in
                guard let family = a.family else { return nil }
                if let given = a.given {
                    return "\(given) \(family)"
                }
                return family
            } ?? []
            let year = item.published?.dateParts?.first?.first
            return SearchResult(
                doi: item.DOI,
                title: title,
                authors: authors,
                journal: item.containerTitle?.first,
                year: year,
                abstract: item.abstract,
                citationCount: item.isReferencedByCount
            )
        }
    }

    /// Fetch metadata for a known DOI
    static func metadata(for doi: String) async throws -> SearchResult? {
        guard let url = URL(string: "\(AppConstants.crossRefBaseURL)/\(doi)") else {
            throw RefSeekError.invalidInput("Invalid DOI")
        }

        struct SingleResponse: Decodable {
            let message: CrossRefResponse.Item
        }

        var request = URLRequest(url: url)
        request.setValue("RefSeek/1.0 (mailto:refseek@example.com)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(SingleResponse.self, from: data)
        let item = decoded.message
        let title = item.title?.first ?? "Unknown Title"
        let authors = item.author?.compactMap { a -> String? in
            guard let family = a.family else { return nil }
            return a.given != nil ? "\(a.given!) \(family)" : family
        } ?? []
        let year = item.published?.dateParts?.first?.first

        return SearchResult(
            doi: item.DOI,
            title: title,
            authors: authors,
            journal: item.containerTitle?.first,
            year: year,
            abstract: item.abstract,
            citationCount: item.isReferencedByCount
        )
    }
}
