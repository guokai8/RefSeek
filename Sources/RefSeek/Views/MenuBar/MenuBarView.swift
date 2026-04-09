import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var store: PaperStore
    @State private var query = ""
    @State private var isSearching = false
    @State private var statusMessage: String?

    private var lastFivePapers: [Paper] {
        Array(store.sortedByDate.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick search
            HStack(spacing: 8) {
                TextField("Quick search (title or DOI)...", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { quickSearch() }

                if isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        quickSearch()
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    .disabled(query.isEmpty)
                }
            }

            if let msg = statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(msg.contains("Error") ? .red : .green)
            }

            Divider()

            // Recent downloads
            if !lastFivePapers.isEmpty {
                Text("Recent Downloads")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(lastFivePapers) { paper in
                    Button {
                        if let path = paper.pdfPath {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        }
                    } label: {
                        HStack {
                            Image(systemName: paper.hasPDF ? "doc.fill" : "doc")
                                .foregroundStyle(paper.hasPDF ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(paper.title)
                                    .lineLimit(1)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Search from clipboard
            Button {
                searchFromClipboard()
            } label: {
                Label("Search from Clipboard (\(HotkeyCombination.load().displayString))", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.plain)
            .font(.caption)

            Text("Tip: Copy text anywhere, then press \(HotkeyCombination.load().displayString)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Divider()

            // Quick actions
            HStack {
                Button("Open Library") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 320)
    }

    private func searchFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Nothing on clipboard"
            return
        }
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        GlobalSearchState.shared.pendingQuery = trimmed
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }
    }

    private func quickSearch() {
        guard !query.isEmpty else { return }
        isSearching = true
        statusMessage = nil

        Task {
            do {
                let fetcher = PaperFetcher()
                let doi: String
                if DOIParser.isDOI(query) {
                    doi = DOIParser.extractDOI(from: query) ?? query
                } else {
                    let results = try await DOIResolver.resolve(title: query)
                    guard let first = results.first else {
                        statusMessage = "No results found"
                        isSearching = false
                        return
                    }
                    doi = first.doi
                }

                let result = try await fetcher.fetchAndSave(doi: doi, store: store)
                statusMessage = "✓ Downloaded: \(result.title)"
                query = ""
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
            isSearching = false
        }
    }
}
