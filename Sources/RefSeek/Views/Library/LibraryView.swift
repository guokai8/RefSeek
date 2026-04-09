import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: PaperStore
    @State private var searchText = ""
    @State private var selectedPaper: Paper?
    @State private var showingExportSheet = false
    @State private var selectedCategory: String? = nil

    var filteredPapers: [Paper] {
        var papers = store.search(searchText)
        if let cat = selectedCategory {
            if cat == "__uncategorized__" {
                papers = papers.filter { $0.category.isEmpty }
            } else {
                papers = papers.filter { $0.category == cat }
            }
        }
        return papers
    }

    var body: some View {
        HSplitView {
            // Paper list with category filter
            VStack(spacing: 0) {
                // Category filter bar
                if !store.categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            CategoryChip(name: "All", icon: "tray.full", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }
                            CategoryChip(name: "Uncategorized", icon: "questionmark.folder", isSelected: selectedCategory == "__uncategorized__") {
                                selectedCategory = "__uncategorized__"
                            }
                            ForEach(store.categories, id: \.self) { cat in
                                CategoryChip(name: cat, icon: "folder.fill", isSelected: selectedCategory == cat) {
                                    selectedCategory = cat
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .background(.bar)
                    Divider()
                }

                if filteredPapers.isEmpty {
                    // Cute cat empty state
                    VStack(spacing: 12) {
                        Spacer()
                        CatMascot(size: 48)
                        Text("No papers here yet...")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Search & download papers, they'll appear in your library!")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(filteredPapers, selection: $selectedPaper) { paper in
                        LibraryPaperRow(paper: paper)
                            .tag(paper)
                            .contextMenu {
                                if paper.hasPDF {
                                    Button("Open PDF") { openPDF(paper) }
                                    Button("Reveal in Finder") { revealInFinder(paper) }
                                    Divider()
                                }
                                // Category submenu
                                Menu("Set Category") {
                                    Button("None") {
                                        paper.category = ""
                                        store.save()
                                    }
                                    Divider()
                                    ForEach(store.categories, id: \.self) { cat in
                                        Button(cat) {
                                            paper.category = cat
                                            store.save()
                                        }
                                    }
                                }
                                Divider()
                                Button("Copy DOI") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(paper.doi, forType: .string)
                                }
                                Button("Copy Citation") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(paper.citation, forType: .string)
                                }
                                Button("Copy BibTeX") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(BibTeXFormatter.format(paper), forType: .string)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    deletePaper(paper)
                                }
                            }
                    }
                    .listStyle(.inset)
                }
            }
            .searchable(text: $searchText, prompt: "Filter papers...")
            .frame(minWidth: 350)

            // Detail panel
            if let paper = selectedPaper {
                PaperDetailView(paper: paper)
                    .frame(minWidth: 300)
            } else {
                VStack(spacing: 12) {
                    CatMascot(size: 48)
                    Text("Select a paper to view details")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Library (\(filteredPapers.count) papers)")
        .toolbar {
            ToolbarItem {
                Button {
                    showingExportSheet = true
                } label: {
                    Label("Export BibTeX", systemImage: "square.and.arrow.up")
                }
                .disabled(store.papers.isEmpty)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportBibTeXSheet(papers: filteredPapers)
        }
    }

    private func openPDF(_ paper: Paper) {
        guard let path = paper.pdfPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func revealInFinder(_ paper: Paper) {
        guard let path = paper.pdfPath else { return }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    private func deletePaper(_ paper: Paper) {
        if selectedPaper == paper { selectedPaper = nil }
        store.remove(paper)
    }
}

struct LibraryPaperRow: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(paper.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if paper.hasPDF {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            if !paper.authors.isEmpty {
                Text(paper.authorString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                if let journal = paper.journal {
                    Text(journal)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                if let year = paper.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                // Category badge
                if !paper.category.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                        Text(paper.category)
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            // Tags
            if !paper.tagNames.isEmpty {
                HStack(spacing: 4) {
                    ForEach(paper.tagNames, id: \.self) { tagName in
                        Text(tagName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CategoryChip: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(name)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
