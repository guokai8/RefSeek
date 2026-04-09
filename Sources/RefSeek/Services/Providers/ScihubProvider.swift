import Foundation

struct ScihubProvider: PaperProvider {
    let name = "Sci-Hub"

    private var mirrors: [String] {
        UserDefaults.standard.stringArray(forKey: AppConstants.scihubMirrorsKey)
            ?? AppConstants.defaultScihubMirrors
    }

    func pdfURL(for doi: String) async throws -> URL? {
        for mirror in mirrors {
            if let url = try? await fetchFromMirror(mirror, doi: doi) {
                return url
            }
        }
        return nil
    }

    private func fetchFromMirror(_ mirror: String, doi: String) async throws -> URL? {
        guard let pageURL = URL(string: "\(mirror)/\(doi)") else { return nil }

        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        guard let html = String(data: data, encoding: .utf8) else { return nil }

        return extractPDFURL(from: html, baseURL: mirror)
    }

    /// Parse the Sci-Hub HTML page to find the embedded PDF URL
    private func extractPDFURL(from html: String, baseURL: String) -> URL? {
        // Patterns ordered by reliability
        let patterns = [
            #"<embed[^>]*src\s*=\s*[\"']([^\"']*\.pdf[^\"']*)[\"']"#,
            #"<iframe[^>]*src\s*=\s*[\"']([^\"']*\.pdf[^\"']*)[\"']"#,
            #"location\.href\s*=\s*[\"']([^\"']*\.pdf[^\"']*)[\"']"#,
            #"<iframe[^>]*src\s*=\s*[\"']([^\"']+)[\"']"#,
        ]

        for pattern in patterns {
            if let url = matchFirst(pattern: pattern, in: html, baseURL: baseURL) {
                return url
            }
        }

        // Fallback: button onclick with escaped slashes (common in newer Sci-Hub)
        // e.g. location.href='https:\/\/sci.bban.top\/pdf\/10.1038\/s41586-019-1711-4.pdf?download=true'
        if let regex = try? NSRegularExpression(pattern: #"location\.href\s*=\s*[\\]?'([^']+)'"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            var urlString = String(html[range])
            // Unescape forward slashes
            urlString = urlString.replacingOccurrences(of: "\\/", with: "/")
            if urlString.contains(".pdf"), let url = resolveURL(urlString, baseURL: baseURL) {
                return url
            }
        }

        return nil
    }

    private func matchFirst(pattern: String, in html: String, baseURL: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let urlString = String(html[range])
        return resolveURL(urlString, baseURL: baseURL)
    }

    private func resolveURL(_ raw: String, baseURL: String) -> URL? {
        var urlString = raw

        // Handle protocol-relative URLs
        if urlString.hasPrefix("//") {
            urlString = "https:" + urlString
        } else if urlString.hasPrefix("/") {
            urlString = baseURL + urlString
        }

        // Remove any fragment
        if let fragmentIndex = urlString.firstIndex(of: "#") {
            urlString = String(urlString[..<fragmentIndex])
        }

        return URL(string: urlString)
    }
}
