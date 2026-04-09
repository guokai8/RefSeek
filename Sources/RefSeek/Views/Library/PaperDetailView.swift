import SwiftUI
import UniformTypeIdentifiers

struct PaperDetailView: View {
    @ObservedObject var paper: Paper
    @EnvironmentObject private var store: PaperStore
    @EnvironmentObject private var embeddingStore: EmbeddingStore
    @State private var newTagName = ""
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var newCategory = ""
    @State private var isSummarizing = false
    @State private var showSummaryExport = false
    @State private var similarPapers: [(paper: Paper, score: Double)] = []
    @State private var suggestedTags: [String] = []
    @State private var isLoadingSuggestions = false
    @State private var isDeepSummarizing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(paper.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .textSelection(.enabled)

                // Metadata
                Group {
                    if !paper.authors.isEmpty {
                        MetadataRow(label: "Authors", value: paper.authorString)
                    }
                    if let journal = paper.journal {
                        MetadataRow(label: "Journal", value: journal)
                    }
                    if let year = paper.year {
                        MetadataRow(label: "Year", value: String(year))
                    }
                    // Clickable DOI
                    HStack(alignment: .top) {
                        Text("DOI")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        Button(paper.doi) {
                            if let url = URL(string: "https://doi.org/\(paper.doi)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                        .font(.callout)
                    }
                    if let source = paper.source {
                        MetadataRow(label: "Source", value: source)
                    }
                    MetadataRow(label: "Added", value: paper.dateAdded.formatted(date: .abbreviated, time: .shortened))
                }

                Divider()

                // Actions
                HStack(spacing: 12) {
                    if paper.hasPDF {
                        Button {
                            if let path = paper.pdfPath {
                                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                            }
                        } label: {
                            Label("Open PDF", systemImage: "doc.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        if isDownloading {
                            ProgressView()
                                .controlSize(.small)
                            Text("Downloading...")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            Button {
                                Task { await redownload() }
                            } label: {
                                Label("Download PDF", systemImage: "arrow.down.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Button {
                        if let url = URL(string: "https://doi.org/\(paper.doi)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open DOI", systemImage: "globe")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(BibTeXFormatter.format(paper), forType: .string)
                    } label: {
                        Label("Copy BibTeX", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(paper.citation, forType: .string)
                    } label: {
                        Label("Copy Citation", systemImage: "text.quote")
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                // Category
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Category")
                            .font(.headline)
                        CatMascot(size: 16)
                    }

                    HStack(spacing: 8) {
                        // Existing categories as quick buttons
                        ForEach(store.categories, id: \.self) { cat in
                            Button {
                                paper.category = cat
                                store.save()
                            } label: {
                                Text(cat)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(paper.category == cat ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        // New category input
                        HStack(spacing: 4) {
                            TextField("New category", text: $newCategory)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                            Button {
                                let cat = newCategory.trimmingCharacters(in: .whitespaces)
                                guard !cat.isEmpty else { return }
                                paper.category = cat
                                store.save()
                                newCategory = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .disabled(newCategory.isEmpty)
                        }

                        if !paper.category.isEmpty {
                            Button {
                                paper.category = ""
                                store.save()
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    if !paper.category.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.orange)
                            Text(paper.category)
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                    }
                }

                Divider()

                // Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.headline)

                    FlowLayout(spacing: 6) {
                        ForEach(paper.tagNames, id: \.self) { tagName in
                            HStack(spacing: 4) {
                                Text(tagName)
                                Button {
                                    paper.tagNames.removeAll { $0 == tagName }
                                    store.save()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        HStack(spacing: 4) {
                            TextField("New tag", text: $newTagName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                            Button {
                                addTag()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .disabled(newTagName.isEmpty)
                        }
                    }
                }

                Divider()

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    TextEditor(text: $paper.notes)
                        .font(.body)
                        .frame(minHeight: 120)
                        .border(Color.secondary.opacity(0.2))
                        .onChange(of: paper.notes) { _, _ in
                            store.save()
                        }
                }

                // Summary
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Summary")
                            .font(.headline)
                        CatMascot(size: 16)
                        Spacer()

                        if isSummarizing || isDeepSummarizing {
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.mini)
                                Text(isDeepSummarizing ? "Deep analysis..." : "Kitty is reading...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            // Quick summary (Apple ML — always available)
                            if paper.abstract != nil || paper.hasPDF {
                                Button {
                                    quickSummarize()
                                } label: {
                                    Label("Quick Summary", systemImage: "text.quote")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Extract key sentences (no AI setup needed)")
                            }

                            // Deep summary (Ollama — optional)
                            if AIService.shared.hasOllama && (paper.abstract != nil || paper.hasPDF) {
                                Button {
                                    Task { await deepSummarize() }
                                } label: {
                                    Label("Deep AI Summary", systemImage: "sparkles")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Structured analysis with local Ollama LLM")
                            }
                        }

                        if !paper.summary.isEmpty {
                            Button {
                                exportSummary()
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(paper.summary, forType: .string)
                            } label: {
                                Label("Copy", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    if paper.summary.isEmpty {
                        Text("No summary yet. Quick Summary works instantly. Deep AI Summary requires Ollama (set up in Settings → AI).")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    TextEditor(text: Binding(
                        get: { paper.summary },
                        set: { paper.summary = $0; store.save() }
                    ))
                        .font(.body)
                        .frame(minHeight: 80)
                        .border(Color.secondary.opacity(0.2))
                }

                // AI Tag Suggestions
                if !suggestedTags.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                            Text("Suggested Tags")
                                .font(.headline)
                        }
                        FlowLayout(spacing: 6) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                Button {
                                    if !paper.tagNames.contains(where: { $0.lowercased() == tag.lowercased() }) {
                                        paper.tagNames.append(tag)
                                        store.addTag(Tag(name: tag))
                                        store.save()
                                    }
                                    suggestedTags.removeAll { $0 == tag }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.caption2)
                                        Text(tag)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.purple.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Similar Papers
                if !similarPapers.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .foregroundStyle(.blue)
                            Text("Similar Papers in Library")
                                .font(.headline)
                            Spacer()
                            Text("\(similarPapers.count) found")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(similarPapers.prefix(5), id: \.paper.id) { item in
                            HStack(spacing: 8) {
                                // Similarity bar
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.gray.opacity(0.15))
                                        .frame(width: 40, height: 6)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(similarityColor(item.score))
                                        .frame(width: CGFloat(item.score) * 40, height: 6)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.paper.title)
                                        .font(.callout)
                                        .lineLimit(2)
                                    HStack(spacing: 6) {
                                        if let year = item.paper.year {
                                            Text(String(year))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let journal = item.paper.journal {
                                            Text(journal)
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                                .lineLimit(1)
                                        }
                                        Text("\(Int(item.score * 100))% similar")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Abstract
                if let abstract = paper.abstract, !abstract.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Abstract")
                            .font(.headline)
                        Text(abstract)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
        .onAppear { loadAIFeatures() }
        .onChange(of: paper.id) { _, _ in loadAIFeatures() }
    }

    private func loadAIFeatures() {
        // Find similar papers (uses Apple NLEmbedding — zero setup)
        similarPapers = embeddingStore.findSimilar(to: paper, in: store.papers, topK: 5)
            .filter { $0.score > 0.3 }

        // Load tag suggestions in background
        if suggestedTags.isEmpty && !isLoadingSuggestions {
            isLoadingSuggestions = true
            Task {
                let existing = store.tags.map(\.name)
                suggestedTags = await AIService.shared.suggestTags(
                    title: paper.title,
                    abstract: paper.abstract,
                    existingTags: existing
                ).filter { tag in
                    !paper.tagNames.contains(where: { $0.lowercased() == tag.lowercased() })
                }
                isLoadingSuggestions = false
            }
        }
    }

    private func similarityColor(_ score: Double) -> Color {
        if score > 0.8 { return .green }
        if score > 0.6 { return .blue }
        if score > 0.4 { return .orange }
        return .gray
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        if !paper.tagNames.contains(where: { $0.lowercased() == name.lowercased() }) {
            paper.tagNames.append(name)
        }
        store.addTag(Tag(name: name))
        store.save()
        newTagName = ""
    }

    private func summarizeWithAI() async {
        guard let abstract = paper.abstract, !abstract.isEmpty else { return }
        isSummarizing = true
        if let summary = await OllamaHelper.summarize(abstract) {
            paper.summary = summary
            store.save()
        } else {
            paper.summary = "⚠️ Could not summarize. Make sure Ollama is running (ollama.com) with a model like llama3.2."
        }
        isSummarizing = false
    }

    /// Quick summary using Apple NaturalLanguage (zero setup)
    private func quickSummarize() {
        isSummarizing = true
        let ai = AIService.shared

        // Try abstract first, then PDF text
        var text = paper.abstract ?? ""
        if text.isEmpty, let pdfPath = paper.pdfPath {
            text = ai.extractPDFText(at: pdfPath, maxPages: 5) ?? ""
        }

        guard !text.isEmpty else {
            paper.summary = "⚠️ No abstract or PDF text available to summarize."
            isSummarizing = false
            return
        }

        paper.summary = ai.extractiveSummary(of: text, sentenceCount: 4)
        store.save()
        isSummarizing = false
    }

    /// Deep structured summary using Ollama LLM
    private func deepSummarize() async {
        isDeepSummarizing = true
        let ai = AIService.shared

        // Get text: abstract or PDF
        var text = paper.abstract ?? ""
        if text.count < 100, let pdfPath = paper.pdfPath {
            text = ai.extractPDFText(at: pdfPath, maxPages: 10) ?? text
        }

        guard !text.isEmpty else {
            paper.summary = "⚠️ No text available to summarize."
            isDeepSummarizing = false
            return
        }

        if let deepSummary = await ai.deepSummarize(text) {
            paper.summary = deepSummary
            store.save()
        } else {
            paper.summary = "⚠️ Deep summary failed. Check Ollama status in Settings → AI."
        }
        isDeepSummarizing = false
    }

    private func exportSummary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(paper.title.prefix(50))_summary.txt"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                let content = """
                Title: \(paper.title)
                Authors: \(paper.authorString)
                Journal: \(paper.journal ?? "N/A")
                Year: \(paper.year.map(String.init) ?? "N/A")
                DOI: \(paper.doi)
                Category: \(paper.category.isEmpty ? "Uncategorized" : paper.category)

                --- Summary ---
                \(paper.summary)

                --- Notes ---
                \(paper.notes)
                """
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func redownload() async {
        isDownloading = true
        downloadError = nil
        do {
            let fetcher = PaperFetcher()
            let (localURL, providerName) = try await fetcher.fetchPDF(doi: paper.doi)
            paper.pdfPath = localURL.path
            paper.source = providerName
            store.save()
        } catch {
            downloadError = error.localizedDescription
        }
        isDownloading = false
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
