import Foundation

class PaperFetcher {
    /// PDF providers tried in order: legal open-access first, Sci-Hub last
    private let providers: [PaperProvider] = [
        UnpaywallProvider(),
        PMCProvider(),
        EuropePMCProvider(),
        SemanticScholarPDFProvider(),
        OpenAlexPDFProvider(),
        ScihubProvider()
    ]

    /// Track which provider succeeded (for UI feedback)
    @Published var lastUsedProvider: String?
    @Published var triedProviders: [String] = []

    /// Download folder path
    private var downloadFolder: String {
        UserDefaults.standard.string(forKey: AppConstants.downloadFolderKey)
            ?? AppConstants.defaultDownloadFolder
    }

    /// Try all providers in order to get a PDF URL, then download it
    func fetchPDF(doi: String, progressHandler: ((Double) -> Void)? = nil) async throws -> (url: URL, provider: String) {
        await MainActor.run {
            triedProviders = []
            lastUsedProvider = nil
        }

        for provider in providers {
            await MainActor.run { triedProviders.append(provider.name) }
            do {
                if let pdfURL = try await provider.pdfURL(for: doi) {
                    // Download the PDF
                    let localURL = try await downloadPDF(from: pdfURL, doi: doi, progressHandler: progressHandler)

                    // Validate
                    guard PDFValidator.isValidPDF(at: localURL.path) else {
                        try? FileManager.default.removeItem(at: localURL)
                        continue
                    }

                    await MainActor.run { lastUsedProvider = provider.name }
                    return (localURL, provider.name)
                }
            } catch {
                // Try next provider
                continue
            }
        }

        throw RefSeekError.noPDFFound("No PDF found from any source for DOI: \(doi)")
    }

    /// Convenience: fetch PDF and save to PaperStore
    @MainActor
    func fetchAndSave(doi: String, store: PaperStore, progressHandler: ((Double) -> Void)? = nil) async throws -> Paper {
        // Get metadata first
        let metadata = try? await DOIResolver.metadata(for: doi)

        // Download PDF
        let (localURL, providerName) = try await fetchPDF(doi: doi, progressHandler: progressHandler)

        // Create or update Paper record
        let paper = Paper(
            doi: doi,
            title: metadata?.title ?? "Unknown Title",
            authors: metadata?.authors ?? [],
            journal: metadata?.journal,
            year: metadata?.year,
            abstract: metadata?.abstract,
            pdfPath: localURL.path,
            source: providerName
        )

        store.add(paper)

        // Auto-summarize if abstract available and Ollama is running
        if let abstract = paper.abstract, !abstract.isEmpty {
            Task.detached { [paper] in
                if await OllamaHelper.isAvailable() {
                    if let summary = await OllamaHelper.summarize(abstract) {
                        await MainActor.run {
                            paper.summary = summary
                            store.save()
                        }
                    }
                }
            }
        }

        return paper
    }

    private func downloadPDF(from url: URL, doi: String, progressHandler: ((Double) -> Void)?) async throws -> URL {
        // Ensure download folder exists
        let folder = URL(fileURLWithPath: downloadFolder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // Sanitize filename from DOI
        let sanitized = doi
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let filename = "\(sanitized).pdf"
        let destination = folder.appendingPathComponent(filename)

        // Download with progress
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        let totalBytes = response.expectedContentLength
        var data = Data()
        if totalBytes > 0 {
            data.reserveCapacity(Int(totalBytes))
        }

        var downloadedBytes: Int64 = 0
        for try await byte in asyncBytes {
            data.append(byte)
            downloadedBytes += 1
            if totalBytes > 0, downloadedBytes % 1024 == 0 {
                let progress = Double(downloadedBytes) / Double(totalBytes)
                await MainActor.run { progressHandler?(min(progress, 1.0)) }
            }
        }

        await MainActor.run { progressHandler?(1.0) }
        try data.write(to: destination)
        return destination
    }
}
