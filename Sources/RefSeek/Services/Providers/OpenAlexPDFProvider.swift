import Foundation

/// Gets open access PDF URLs from OpenAlex
struct OpenAlexPDFProvider: PaperProvider {
    let name = "OpenAlex"

    struct OAResponse: Decodable {
        let bestOaLocation: OALocation?
        let openAccess: OpenAccess?
        let primaryLocation: OALocation?

        enum CodingKeys: String, CodingKey {
            case bestOaLocation = "best_oa_location"
            case openAccess = "open_access"
            case primaryLocation = "primary_location"
        }
    }

    struct OpenAccess: Decodable {
        let oaUrl: String?
        enum CodingKeys: String, CodingKey {
            case oaUrl = "oa_url"
        }
    }

    struct OALocation: Decodable {
        let pdfUrl: String?
        let landingPageUrl: String?
        enum CodingKeys: String, CodingKey {
            case pdfUrl = "pdf_url"
            case landingPageUrl = "landing_page_url"
        }
    }

    func pdfURL(for doi: String) async throws -> URL? {
        guard let encoded = doi.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.openalex.org/works/doi:\(encoded)?select=best_oa_location,open_access,primary_location") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("\(AppConstants.appName)/\(AppConstants.appVersion) (mailto:\(AppConstants.contactEmail))", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(OAResponse.self, from: data)

        // Best OA location PDF
        if let pdfStr = decoded.bestOaLocation?.pdfUrl, let pdfURL = URL(string: pdfStr) {
            return pdfURL
        }

        // Primary location PDF
        if let pdfStr = decoded.primaryLocation?.pdfUrl, let pdfURL = URL(string: pdfStr) {
            return pdfURL
        }

        // OA URL (may be a landing page, but worth trying)
        if let oaStr = decoded.openAccess?.oaUrl, let oaURL = URL(string: oaStr),
           oaStr.hasSuffix(".pdf") {
            return oaURL
        }

        return nil
    }
}
