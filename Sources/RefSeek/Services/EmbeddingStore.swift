import Foundation

/// Persists paper embeddings to disk and provides similarity queries.
/// Uses Apple NLEmbedding vectors — computed locally with zero setup.
@MainActor
class EmbeddingStore: ObservableObject {

    struct PaperEmbedding: Codable {
        let paperId: UUID
        let vector: [Double]
    }

    @Published var embeddings: [UUID: [Double]] = [:]
    @Published var isIndexing = false

    private let fileURL: URL
    private let ai = AIService.shared

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dataDir = appSupport.appendingPathComponent("RefSeek", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        fileURL = dataDir.appendingPathComponent("embeddings.json")
        load()
    }

    // MARK: - Index

    /// Build embeddings for papers that don't have one yet.
    func indexPapers(_ papers: [Paper]) async {
        isIndexing = true
        let toIndex = papers.filter { embeddings[$0.id] == nil }

        for paper in toIndex {
            let text = embeddingText(for: paper)
            if let vec = ai.embedding(for: text) {
                embeddings[paper.id] = vec
            }
        }

        if !toIndex.isEmpty {
            save()
        }
        isIndexing = false
    }

    /// Force re-embed a single paper
    func reindex(paper: Paper) {
        let text = embeddingText(for: paper)
        if let vec = ai.embedding(for: text) {
            embeddings[paper.id] = vec
        }
        save()
    }

    // MARK: - Query

    /// Find papers similar to the given paper, sorted by similarity (descending).
    func findSimilar(to paper: Paper, in papers: [Paper], topK: Int = 8) -> [(paper: Paper, score: Double)] {
        guard let queryVec = embeddings[paper.id] else { return [] }

        var results: [(paper: Paper, score: Double)] = []
        for other in papers where other.id != paper.id {
            guard let otherVec = embeddings[other.id] else { continue }
            let score = cosineSimilarity(queryVec, otherVec)
            results.append((other, score))
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }

    /// Find papers similar to arbitrary text
    func findSimilar(toText text: String, in papers: [Paper], topK: Int = 8) -> [(paper: Paper, score: Double)] {
        guard let queryVec = ai.embedding(for: text) else { return [] }

        var results: [(paper: Paper, score: Double)] = []
        for paper in papers {
            guard let paperVec = embeddings[paper.id] else { continue }
            let score = cosineSimilarity(queryVec, paperVec)
            results.append((paper, score))
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }

    /// Cluster papers by similarity. Returns groups of paper IDs.
    func clusterPapers(_ papers: [Paper], threshold: Double = 0.7) -> [[UUID]] {
        var visited = Set<UUID>()
        var clusters: [[UUID]] = []

        for paper in papers {
            guard !visited.contains(paper.id), embeddings[paper.id] != nil else { continue }
            var cluster = [paper.id]
            visited.insert(paper.id)

            for other in papers where other.id != paper.id && !visited.contains(other.id) {
                guard let v1 = embeddings[paper.id], let v2 = embeddings[other.id] else { continue }
                if cosineSimilarity(v1, v2) >= threshold {
                    cluster.append(other.id)
                    visited.insert(other.id)
                }
            }

            clusters.append(cluster)
        }

        return clusters.sorted { $0.count > $1.count }
    }

    // MARK: - Persistence

    private func save() {
        let entries = embeddings.map { PaperEmbedding(paperId: $0.key, vector: $0.value) }
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("EmbeddingStore save error: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let entries = try JSONDecoder().decode([PaperEmbedding].self, from: data)
            embeddings = Dictionary(uniqueKeysWithValues: entries.map { ($0.paperId, $0.vector) })
        } catch {
            print("EmbeddingStore load error: \(error)")
        }
    }

    // MARK: - Private

    private func embeddingText(for paper: Paper) -> String {
        var parts = [paper.title]
        if let abstract = paper.abstract { parts.append(abstract) }
        if let journal = paper.journal { parts.append(journal) }
        if !paper.tagNames.isEmpty { parts.append(paper.tagNames.joined(separator: " ")) }
        return parts.joined(separator: ". ")
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
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
