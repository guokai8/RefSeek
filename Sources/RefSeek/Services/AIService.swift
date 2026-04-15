import Foundation
import NaturalLanguage
import PDFKit

/// Unified AI service that provides zero-setup Apple ML features
/// and optional enhanced features via managed Ollama.
@MainActor
class AIService: ObservableObject {

    static let shared = AIService()

    @Published var ollamaStatus: OllamaStatus = .unknown
    @Published var ollamaModel: String = ""

    enum OllamaStatus: Equatable {
        case unknown
        case unavailable
        case available
        case downloading(Double)  // model pull progress
    }

    /// Whether Ollama-powered features are available
    var hasOllama: Bool { ollamaStatus == .available }

    private init() {
        Task { await checkOllama() }
    }

    func checkOllama() async {
        if await OllamaHelper.isAvailable() {
            ollamaStatus = .available
            let models = await OllamaHelper.availableModels()
            ollamaModel = models.first ?? ""
        } else if OllamaManager.isInstalled {
            // Installed but not running — try starting
            OllamaManager.start()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if await OllamaHelper.isAvailable() {
                ollamaStatus = .available
                let models = await OllamaHelper.availableModels()
                ollamaModel = models.first ?? ""
            } else {
                ollamaStatus = .unavailable
            }
        } else {
            ollamaStatus = .unavailable
        }
    }

    // MARK: - Embeddings (Apple NaturalLanguage — zero setup)

    /// Compute a text embedding using Apple's built-in NLEmbedding.
    /// Returns nil only if the system language model is unavailable.
    nonisolated func embedding(for text: String) -> [Double]? {
        guard let nlEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        guard let vector = nlEmbedding.vector(for: text) else { return nil }
        return vector
    }

    /// Find the N most similar strings to `query` from `candidates` using Apple NLEmbedding.
    nonisolated func findSimilar(query: String, candidates: [(id: UUID, text: String)], topK: Int = 5) -> [(id: UUID, score: Double)] {
        guard let queryVec = embedding(for: query) else { return [] }

        var scored: [(id: UUID, score: Double)] = []
        for candidate in candidates {
            guard let candVec = embedding(for: candidate.text) else { continue }
            let sim = cosineSimilarity(queryVec, candVec)
            scored.append((candidate.id, sim))
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }

    // MARK: - PDF Text Extraction (PDFKit — zero setup)

    /// Extract text from a PDF file at the given path.
    nonisolated func extractPDFText(at path: String, maxPages: Int = 20) -> String? {
        guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else { return nil }
        let pageCount = min(doc.pageCount, maxPages)
        var text = ""
        for i in 0..<pageCount {
            if let page = doc.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Extractive Summary (zero setup, no LLM)

    /// Create a summary by extracting the most important sentences.
    /// Uses NLEmbedding similarity to the full text to rank sentences.
    nonisolated func extractiveSummary(of text: String, sentenceCount: Int = 5) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if s.count > 20 {  // skip very short fragments
                sentences.append(s)
            }
            return true
        }

        guard sentences.count > sentenceCount else { return text }

        // Score each sentence by embedding similarity to the full text
        guard let nlEmbedding = NLEmbedding.sentenceEmbedding(for: .english),
              let fullVec = nlEmbedding.vector(for: String(text.prefix(1000))) else {
            // Fallback: return first N sentences
            return sentences.prefix(sentenceCount).joined(separator: " ")
        }

        var scored: [(index: Int, score: Double, text: String)] = []
        for (i, sentence) in sentences.enumerated() {
            if let vec = nlEmbedding.vector(for: sentence) {
                let sim = cosineSimilarity(fullVec, vec)
                scored.append((i, sim, sentence))
            }
        }

        // Pick top sentences by score, then sort by original order
        let top = scored
            .sorted { $0.score > $1.score }
            .prefix(sentenceCount)
            .sorted { $0.index < $1.index }

        return top.map(\.text).joined(separator: " ")
    }

    // MARK: - Keyword Extraction (Apple NLTagger — zero setup)

    /// Extract key terms from text using NLTagger.
    nonisolated func extractKeywords(from text: String, maxKeywords: Int = 10) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var nounCounts: [String: Int] = [:]
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: options) { tag, range in
            if let tag = tag, (tag == .noun || tag == .adjective) {
                let word = String(text[range]).lowercased()
                if word.count > 2 {
                    nounCounts[word, default: 0] += 1
                }
            }
            return true
        }

        return nounCounts
            .sorted { $0.value > $1.value }
            .prefix(maxKeywords)
            .map(\.key)
    }

    // MARK: - Deep Summarize (Ollama — optional)

    /// Structured summarization using Ollama LLM.
    /// Returns nil if Ollama is not available.
    func deepSummarize(_ text: String) async -> String? {
        guard hasOllama, !ollamaModel.isEmpty else { return nil }
        let model = ollamaModel

        let prompt = """
        You are an expert academic reader. Analyze this paper text and provide a structured summary.
        Use this exact format:

        **Key Findings:** (2-3 sentences about the main results)
        **Methods:** (1-2 sentences about the methodology)
        **Significance:** (1 sentence about why this matters)
        **Limitations:** (1 sentence about caveats or limitations, if apparent)

        Paper text:
        \(String(text.prefix(4000)))

        Structured summary:
        """

        return await OllamaHelper.generate(prompt: prompt, model: model, timeout: 90)
    }

    /// Suggest tags for a paper based on its content.
    func suggestTags(title: String, abstract: String?, existingTags: [String]) async -> [String] {
        // Tier 1: keyword extraction (always works)
        let text = [title, abstract ?? ""].joined(separator: ". ")
        var keywords = extractKeywords(from: text, maxKeywords: 8)

        // Tier 2: if Ollama available, ask for smarter suggestions
        if hasOllama, !ollamaModel.isEmpty {
            let existingList = existingTags.isEmpty ? "none yet" : existingTags.joined(separator: ", ")
            let prompt = """
            Suggest 3-5 short academic tags for this paper. Return ONLY a comma-separated list.
            Existing tags in the library: \(existingList)
            Prefer existing tags when relevant, but suggest new ones if needed.

            Title: \(title)
            Abstract: \(abstract?.prefix(500) ?? "N/A")

            Tags:
            """
            if let response = await OllamaHelper.generate(prompt: prompt, model: ollamaModel, timeout: 30) {
                let aiTags = response.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty && $0.count < 40 }
                keywords = aiTags + keywords
            }
        }

        // Deduplicate
        var seen = Set<String>()
        return keywords.filter { seen.insert($0.lowercased()).inserted }.prefix(8).map { $0 }
    }

    // MARK: - Private: Math

    nonisolated private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }
}
