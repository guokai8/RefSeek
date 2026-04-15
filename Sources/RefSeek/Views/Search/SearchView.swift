import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: PaperStore
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject private var globalSearch = GlobalSearchState.shared
    @FocusState private var isSearchFocused: Bool
    @State private var showAdvanced = false
    @State private var advTitle = ""
    @State private var advAuthor = ""
    @State private var advJournal = ""
    @State private var advYearFrom = ""
    @State private var advYearTo = ""
    @State private var advAbstract = ""
    @State private var advOpenAccessOnly = false
    @State private var advMinCitations = ""

    var body: some View {
        VStack(spacing: 0) {
            // ── Search bar ──────────────────────────────
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    // macOS-native search field style
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.body)
                        TextField("Search papers — title, DOI, or author:Name year:2020...", text: $viewModel.query)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .focused($isSearchFocused)
                            .onSubmit { Task { await viewModel.search() } }
                        if !viewModel.query.isEmpty {
                            Button {
                                viewModel.query = ""
                                viewModel.results = []
                                viewModel.errorMessage = nil
                                viewModel.parsedQuery = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(isSearchFocused ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1))

                    if viewModel.isSearching {
                        HStack(spacing: 4) {
                            CatMascot(size: 18)
                            ProgressView().controlSize(.small)
                        }
                    }

                    Button {
                        Task { await viewModel.search() }
                    } label: {
                        Text("Search")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSearching)
                }

                // ── Engine picker + query type indicator ──
                HStack(spacing: 6) {
                    // Engine picker
                    Picker(selection: Binding(
                        get: { viewModel.searchEngine },
                        set: { viewModel.setEngine($0) }
                    )) {
                        ForEach(SearchEngine.allCases) { engine in
                            Label(engine.rawValue, systemImage: engine.icon).tag(engine)
                        }
                    } label: {
                        Label(viewModel.searchEngine.rawValue, systemImage: viewModel.searchEngine.icon)
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    .font(.caption)

                    Divider().frame(height: 14)

                    // LLM expand toggle (only visible if Ollama running)
                    if viewModel.llmAvailable {
                        Toggle(isOn: $viewModel.useLLMExpand) {
                            Label("AI", systemImage: "sparkles")
                        }
                        .toggleStyle(.button)
                        .controlSize(.small)
                        .help("Use local Ollama LLM to expand your query")

                        Divider().frame(height: 14)
                    }

                    if !viewModel.query.isEmpty && !viewModel.isSearching {
                        if DOIParser.isDOI(viewModel.query) {
                            Label("DOI lookup", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if viewModel.isStructuredQuery {
                            Label("Structured", systemImage: "line.3.horizontal.decrease.circle.fill")
                                .foregroundStyle(.purple)
                        } else {
                            Label("Keyword search", systemImage: "text.magnifyingglass")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let expanded = viewModel.expandedQuery {
                        Label("AI → \(expanded)", systemImage: "sparkles")
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }

                    if let parsed = viewModel.parsedQuery {
                        Text(parsed.description)
                            .foregroundStyle(.purple)
                    }

                    Spacer()

                    // Advanced toggle
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showAdvanced.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Advanced")
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(showAdvanced ? Color.accentColor : .secondary)
                    .font(.caption)
                }
                .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            // ── Advanced search form ────────────────────
            if showAdvanced {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        LabeledField("Title", text: $advTitle)
                        LabeledField("Author", text: $advAuthor)
                    }
                    HStack(spacing: 12) {
                        LabeledField("Journal", text: $advJournal)
                        HStack(spacing: 6) {
                            LabeledField("Year", text: $advYearFrom)
                            Text("–").foregroundStyle(.secondary)
                            TextField("to", text: $advYearTo)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                        }
                    }
                    HStack(spacing: 12) {
                        LabeledField("Abstract", text: $advAbstract)
                        HStack(spacing: 10) {
                            LabeledField("Min Cites", text: $advMinCitations)
                            Toggle(isOn: $advOpenAccessOnly) {
                                Label("OA Only", systemImage: "lock.open")
                                    .font(.caption)
                            }
                            .toggleStyle(.checkbox)
                            .fixedSize()
                        }
                    }
                    HStack {
                        Text("Use fields above or type syntax like  author:Smith year:2020  in the search bar")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button("Clear") {
                            advTitle = ""; advAuthor = ""; advJournal = ""
                            advYearFrom = ""; advYearTo = ""; advAbstract = ""
                            advMinCitations = ""; advOpenAccessOnly = false
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        Button("Apply & Search") { applyAdvancedSearch() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar.opacity(0.6))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            // ── Content area ────────────────────────────
            if viewModel.results.isEmpty && !viewModel.isSearching {
                emptyStateView
            } else {
                resultsList
            }

            // ── Error banner ────────────────────────────
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.callout)
                    Spacer()
                    Button { withAnimation { viewModel.errorMessage = nil } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.red.opacity(0.08))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAdvanced)
        .navigationTitle("Search")
        .onAppear { isSearchFocused = true }
        .onChange(of: globalSearch.pendingQuery) { newQuery in
            if let query = newQuery, !query.isEmpty {
                viewModel.query = query
                globalSearch.pendingQuery = nil
                isSearchFocused = true
                Task { await viewModel.search() }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Recent searches
                if !viewModel.searchHistory.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(viewModel.searchHistory.prefix(6), id: \.self) { item in
                                Button {
                                    viewModel.query = item
                                    Task { await viewModel.search() }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 16)
                                        Text(item)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .foregroundStyle(.quaternary)
                                    }
                                    .font(.callout)
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } label: {
                        HStack {
                            Label("Recent Searches", systemImage: "clock.arrow.circlepath")
                            Spacer()
                            Button("Clear All") { viewModel.clearHistory() }
                                .buttonStyle(.borderless)
                                .font(.caption)
                        }
                    }
                }

                // Welcome card with cat mascot
                GroupBox {
                    VStack(spacing: 12) {
                        // Cute cat mascot
                        CatMascot(size: 64)
                        Text("Meow! Let me find papers for you~")
                            .font(.headline)
                        Text("I'll search PubMed, CrossRef, Semantic Scholar & OpenAlex")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            HintItem(icon: "text.cursor", text: "Type keywords, paper title, or author name")
                            HintItem(icon: "number", text: "Paste a DOI like 10.1038/s41586-019-1711-4")
                            HintItem(icon: "arrow.down.circle", text: "Click Download to save the PDF locally")
                            HintItem(icon: "keyboard", text: "Shortcuts: ⌘1 Search · ⌘2 Library · ⌘3 Batch")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Advanced search guide
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You can type field-qualified queries directly, or use the Advanced panel above.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        ExampleQuery(label: "Author + Title + Year", query: "CRISPR author:Doudna year:2020")
                        ExampleQuery(label: "Quoted phrase", query: "title:\"genome editing\" journal:Nature")
                        ExampleQuery(label: "NCBI bracket style", query: "Doudna[au] CRISPR[ti] 2020[dp]")
                        ExampleQuery(label: "Year range", query: "author:Zhang year:2019-2023")
                    }
                } label: {
                    Label("Advanced Search (NCBI-style)", systemImage: "slider.horizontal.3")
                }
            }
            .padding()
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        VStack(spacing: 0) {
            // ── Bulk actions toolbar ──
            HStack(spacing: 10) {
                // Select all toggle
                Button {
                    viewModel.toggleSelectAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.allSelected ? "checkmark.square.fill" : "square")
                        Text(viewModel.allSelected ? "Deselect All" : "Select All")
                    }
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Text("\(viewModel.results.count) result\(viewModel.results.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("via \(viewModel.searchEngine.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.blue)

                if let parsed = viewModel.parsedQuery {
                    Text("· \(parsed.description)")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }

                Spacer()

                // Sort picker
                Picker(selection: $viewModel.sortOption) {
                    ForEach(SearchSortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.icon).tag(option)
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .pickerStyle(.menu)
                .fixedSize()
                .font(.caption)

                if viewModel.isDownloadingAll {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        let completed = viewModel.results.filter { $0.downloadStatus == .completed }.count
                        Text("\(completed)/\(viewModel.results.count)")
                            .font(.caption)
                            .monospacedDigit()
                    }
                }

                // Download Selected
                if !viewModel.selectedResultIDs.isEmpty {
                    let selectedCount = viewModel.selectedResultIDs.count
                    Button {
                        Task { await viewModel.downloadMultiple(ids: viewModel.selectedResultIDs, store: store) }
                    } label: {
                        Label("Download \(selectedCount) Selected", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.isDownloadingAll)
                }

                // Download All
                Button {
                    Task { await viewModel.downloadMultiple(store: store) }
                } label: {
                    Label("Download All", systemImage: "arrow.down.to.line.compact")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.results.isEmpty || viewModel.isDownloadingAll)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            // ── Results list ──
            List {
                ForEach(viewModel.sortedResults) { result in
                    HStack(spacing: 8) {
                        // Selection checkbox
                        Button {
                            if viewModel.selectedResultIDs.contains(result.id) {
                                viewModel.selectedResultIDs.remove(result.id)
                            } else {
                                viewModel.selectedResultIDs.insert(result.id)
                            }
                        } label: {
                            Image(systemName: viewModel.selectedResultIDs.contains(result.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(viewModel.selectedResultIDs.contains(result.id)
                                                 ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        SearchResultRow(result: viewModel.enriched(result)) {
                            Task { await viewModel.download(result: result, store: store) }
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    // MARK: - Actions

    private func applyAdvancedSearch() {
        var parts: [String] = []
        let t = advTitle.trimmingCharacters(in: .whitespaces)
        let a = advAuthor.trimmingCharacters(in: .whitespaces)
        let j = advJournal.trimmingCharacters(in: .whitespaces)
        let yf = advYearFrom.trimmingCharacters(in: .whitespaces)
        let yt = advYearTo.trimmingCharacters(in: .whitespaces)
        let ab = advAbstract.trimmingCharacters(in: .whitespaces)

        if !t.isEmpty { parts.append(t.contains(" ") ? "title:\"\(t)\"" : "title:\(t)") }
        if !a.isEmpty { parts.append(a.contains(" ") ? "author:\"\(a)\"" : "author:\(a)") }
        if !j.isEmpty { parts.append(j.contains(" ") ? "journal:\"\(j)\"" : "journal:\(j)") }
        if !yf.isEmpty {
            if !yt.isEmpty && yt != yf {
                parts.append("year:\(yf)-\(yt)")
            } else {
                parts.append("year:\(yf)")
            }
        }
        // Abstract keywords go into general terms (most APIs search full text)
        if !ab.isEmpty { parts.append(ab) }

        if !parts.isEmpty {
            viewModel.query = parts.joined(separator: " ")
            Task {
                await viewModel.search()
                // Post-search client-side filters
                applyPostSearchFilters()
            }
        }
    }

    /// Apply client-side filters after search (OA-only, min citations)
    private func applyPostSearchFilters() {
        let minCites = Int(advMinCitations.trimmingCharacters(in: .whitespaces)) ?? 0
        if advOpenAccessOnly || minCites > 0 {
            viewModel.results = viewModel.results.filter { result in
                if advOpenAccessOnly && result.isOpenAccess != true { return false }
                if minCites > 0, let cites = result.citationCount, cites < minCites { return false }
                if minCites > 0 && result.citationCount == nil { return false }
                return true
            }
            if viewModel.results.isEmpty {
                viewModel.errorMessage = "No results match the filters (OA: \(advOpenAccessOnly), min citations: \(minCites))"
            }
        }
    }
}

// MARK: - Subviews

private struct LabeledField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }
}

private struct HintItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExampleQuery: View {
    let label: String
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(query)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.purple)
                .textSelection(.enabled)
        }
    }
}
