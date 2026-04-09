import Foundation

struct PMCProvider: PaperProvider {
    let name = "PubMed Central"

    struct IDConverterResponse: Decodable {
        let records: [Record]?
    }

    struct Record: Decodable {
        let pmcid: String?
    }

    func pdfURL(for doi: String) async throws -> URL? {
        // Step 1: Convert DOI to PMCID
        guard let pmcid = try await doiToPMCID(doi) else { return nil }

        // Step 2: Construct PDF URL
        // PMC PDFs are at: https://www.ncbi.nlm.nih.gov/pmc/articles/PMCxxxxxx/pdf/
        let pdfPageURL = URL(string: "https://www.ncbi.nlm.nih.gov/pmc/articles/\(pmcid)/pdf/")!

        // Verify it exists
        var request = URLRequest(url: pdfPageURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...399).contains(http.statusCode) else {
            return nil
        }

        return pdfPageURL
    }

    private func doiToPMCID(_ doi: String) async throws -> String? {
        guard let encoded = doi.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(AppConstants.pmcIdConverterURL)?ids=\(encoded)&format=json") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(IDConverterResponse.self, from: data)
        return decoded.records?.first?.pmcid
    }
}
