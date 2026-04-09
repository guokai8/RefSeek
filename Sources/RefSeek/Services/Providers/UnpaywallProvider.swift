import Foundation

struct UnpaywallProvider: PaperProvider {
    let name = "Unpaywall"

    struct UnpaywallResponse: Decodable {
        let bestOaLocation: OALocation?
        enum CodingKeys: String, CodingKey {
            case bestOaLocation = "best_oa_location"
        }
    }

    struct OALocation: Decodable {
        let urlForPdf: String?
        let url: String?
        enum CodingKeys: String, CodingKey {
            case urlForPdf = "url_for_pdf"
            case url
        }
    }

    func pdfURL(for doi: String) async throws -> URL? {
        let email = UserDefaults.standard.string(forKey: AppConstants.unpaywallEmailKey) ?? ""
        guard !email.isEmpty else { return nil }

        guard let encoded = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(AppConstants.unpaywallBaseURL)/\(encoded)?email=\(email)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(UnpaywallResponse.self, from: data)
        if let pdfUrlStr = decoded.bestOaLocation?.urlForPdf, let pdfUrl = URL(string: pdfUrlStr) {
            return pdfUrl
        }
        if let urlStr = decoded.bestOaLocation?.url, let fallbackUrl = URL(string: urlStr) {
            return fallbackUrl
        }
        return nil
    }
}
