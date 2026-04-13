import Foundation

/// Europe PMC — large open access repository, especially good for recent articles
struct EuropePMCProvider: PaperProvider {
    let name = "Europe PMC"

    struct SearchResponse: Decodable {
        let resultList: ResultList?
    }

    struct ResultList: Decodable {
        let result: [PMCResult]?
    }

    struct PMCResult: Decodable {
        let pmcid: String?
        let fullTextUrlList: FullTextUrlList?
    }

    struct FullTextUrlList: Decodable {
        let fullTextUrl: [FullTextUrl]?
    }

    struct FullTextUrl: Decodable {
        let documentStyle: String?
        let url: String?
        let availabilityCode: String?
    }

    func pdfURL(for doi: String) async throws -> URL? {
        guard let encoded = doi.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:\(encoded)&resultType=core&format=json") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard let result = decoded.resultList?.result?.first else { return nil }

        // Look for PDF in full text URLs
        if let urls = result.fullTextUrlList?.fullTextUrl {
            // Prefer PDF
            if let pdfEntry = urls.first(where: { $0.documentStyle?.lowercased() == "pdf" }),
               let pdfStr = pdfEntry.url, let pdfURL = URL(string: pdfStr) {
                return pdfURL
            }
        }

        // Fallback: Europe PMC direct PDF via PMCID
        if let pmcid = result.pmcid {
            let epdfURL = URL(string: "https://europepmc.org/backend/ptpmcrender.fcgi?accid=\(pmcid)&blobtype=pdf")!
            // Verify it exists
            var headReq = URLRequest(url: epdfURL)
            headReq.httpMethod = "HEAD"
            headReq.timeoutInterval = 8
            let (_, headResp) = try await URLSession.shared.data(for: headReq)
            if let headHttp = headResp as? HTTPURLResponse, (200...399).contains(headHttp.statusCode) {
                return epdfURL
            }
        }

        return nil
    }
}
