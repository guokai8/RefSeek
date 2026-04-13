import Foundation

/// Tries to get a PDF URL from Semantic Scholar's open access data
struct SemanticScholarPDFProvider: PaperProvider {
    let name = "Semantic Scholar"

    struct S2PaperResponse: Decodable {
        let openAccessPdf: OAPdf?
        let isOpenAccess: Bool?
        let externalIds: ExternalIds?
    }

    struct OAPdf: Decodable {
        let url: String?
    }

    struct ExternalIds: Decodable {
        let ArXiv: String?
    }

    func pdfURL(for doi: String) async throws -> URL? {
        guard let encoded = doi.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.semanticscholar.org/graph/v1/paper/DOI:\(encoded)?fields=openAccessPdf,isOpenAccess,externalIds") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("RefSeek/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(S2PaperResponse.self, from: data)

        // Direct OA PDF link
        if let pdfURLStr = decoded.openAccessPdf?.url, let pdfURL = URL(string: pdfURLStr) {
            return pdfURL
        }

        // Fallback: ArXiv PDF
        if let arxivId = decoded.externalIds?.ArXiv {
            return URL(string: "https://arxiv.org/pdf/\(arxivId).pdf")
        }

        return nil
    }
}
