import Foundation
import Combine

/// JSON file-based persistence for papers and tags
@MainActor
class PaperStore: ObservableObject {
    @Published var papers: [Paper] = []
    @Published var tags: [Tag] = []

    private let papersFileURL: URL
    private let tagsFileURL: URL
    private let categoriesFileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// User-created categories (persisted separately from papers so empty categories survive)
    @Published var knownCategories: [String] = []

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dataDir = appSupport.appendingPathComponent("RefSeek", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        papersFileURL = dataDir.appendingPathComponent("papers.json")
        tagsFileURL = dataDir.appendingPathComponent("tags.json")
        categoriesFileURL = dataDir.appendingPathComponent("categories.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    // MARK: - CRUD

    func add(_ paper: Paper) {
        // Avoid duplicates by DOI
        if !papers.contains(where: { $0.doi.lowercased() == paper.doi.lowercased() }) {
            papers.insert(paper, at: 0)
            save()
        }
    }

    func remove(_ paper: Paper) {
        papers.removeAll { $0.id == paper.id }
        save()
    }

    func update(_ paper: Paper) {
        save()
    }

    func paper(forDOI doi: String) -> Paper? {
        papers.first { $0.doi.lowercased() == doi.lowercased() }
    }

    // MARK: - Tags

    func addTag(_ tag: Tag) {
        if !tags.contains(where: { $0.name.lowercased() == tag.name.lowercased() }) {
            tags.append(tag)
            saveTags()
        }
    }

    func removeTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
        // Remove from all papers
        for paper in papers {
            paper.tagNames.removeAll { $0.lowercased() == tag.name.lowercased() }
        }
        save()
        saveTags()
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try encoder.encode(papers)
            try data.write(to: papersFileURL, options: .atomic)
        } catch {
            print("Failed to save papers: \(error)")
        }
    }

    private func saveTags() {
        do {
            let data = try encoder.encode(tags)
            try data.write(to: tagsFileURL, options: .atomic)
        } catch {
            print("Failed to save tags: \(error)")
        }
    }

    private func load() {
        // Load papers
        if let data = try? Data(contentsOf: papersFileURL) {
            papers = (try? decoder.decode([Paper].self, from: data)) ?? []
        }
        // Load tags
        if let data = try? Data(contentsOf: tagsFileURL) {
            tags = (try? decoder.decode([Tag].self, from: data)) ?? []
        }
        // Load known categories
        if let data = try? Data(contentsOf: categoriesFileURL) {
            knownCategories = (try? decoder.decode([String].self, from: data)) ?? []
        }
    }

    private func saveCategories() {
        do {
            let data = try encoder.encode(knownCategories)
            try data.write(to: categoriesFileURL, options: .atomic)
        } catch {
            print("Failed to save categories: \(error)")
        }
    }

    // MARK: - Categories

    /// All categories: union of known (user-created) + paper-derived
    var categories: [String] {
        var all = Set(knownCategories)
        for paper in papers where !paper.category.isEmpty {
            all.insert(paper.category)
        }
        return all.sorted()
    }

    func papers(inCategory category: String) -> [Paper] {
        papers.filter { $0.category == category }.sorted { $0.dateAdded > $1.dateAdded }
    }

    var uncategorizedPapers: [Paper] {
        papers.filter { $0.category.isEmpty }.sorted { $0.dateAdded > $1.dateAdded }
    }

    func setCategory(_ category: String, for paper: Paper) {
        paper.category = category
        if !category.isEmpty && !knownCategories.contains(category) {
            knownCategories.append(category)
            saveCategories()
        }
        save()
    }

    func addCategory(_ name: String) {
        guard !name.isEmpty, !knownCategories.contains(name) else { return }
        knownCategories.append(name)
        saveCategories()
    }

    func renameCategory(_ oldName: String, to newName: String) {
        // Update all papers
        for paper in papers where paper.category == oldName {
            paper.category = newName
        }
        // Update known list
        if let idx = knownCategories.firstIndex(of: oldName) {
            knownCategories[idx] = newName
        }
        save()
        saveCategories()
    }

    func deleteCategory(_ name: String) {
        // Remove category from all papers (they become uncategorized)
        for paper in papers where paper.category == name {
            paper.category = ""
        }
        knownCategories.removeAll { $0 == name }
        save()
        saveCategories()
    }

    // MARK: - Sorted/Filtered accessors

    var sortedByDate: [Paper] {
        papers.sorted { $0.dateAdded > $1.dateAdded }
    }

    func search(_ query: String) -> [Paper] {
        guard !query.isEmpty else { return sortedByDate }
        let q = query.lowercased()
        return sortedByDate.filter {
            $0.title.lowercased().contains(q) ||
            $0.doi.lowercased().contains(q) ||
            $0.authorString.lowercased().contains(q) ||
            ($0.journal?.lowercased().contains(q) ?? false) ||
            $0.category.lowercased().contains(q)
        }
    }
}
