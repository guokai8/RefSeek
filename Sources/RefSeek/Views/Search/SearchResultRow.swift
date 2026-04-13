import SwiftUI

struct SearchResultRow: View {
    @EnvironmentObject private var store: PaperStore
    let result: SearchResult
    let onDownload: () -> Void
    @State private var showCategoryPicker = false
    @State private var newCategory = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(result.title)
                .font(.headline)
                .lineLimit(3)

            // Authors
            if !result.authors.isEmpty {
                Text(result.authors.prefix(5).joined(separator: ", ") +
                     (result.authors.count > 5 ? " et al." : ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Metadata badges
            HStack(spacing: 8) {
                if let journal = result.journal {
                    MetadataBadge(text: journal, color: .blue)
                }
                if let year = result.year {
                    MetadataBadge(text: String(year), color: .gray)
                }
                if let citations = result.citationCount {
                    MetadataBadge(text: "\(citations) cited", color: .orange)
                }
                if let impactFactor = result.journalImpactFactor {
                    let prefix = result.ifSource == "JCR" ? "IF:" : "IF~"
                    MetadataBadge(text: String(format: "\(prefix) %.1f", impactFactor), color: .purple)
                }
                if let quartile = result.jcrQuartile {
                    MetadataBadge(
                        text: quartile,
                        color: quartile == "Q1" ? .red :
                               quartile == "Q2" ? .orange :
                               quartile == "Q3" ? .yellow : .gray
                    )
                }
                if result.isOpenAccess == true {
                    MetadataBadge(text: "Open Access", color: .green)
                }
                if !result.doi.isEmpty {
                    Text(result.doi)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else if let pmid = result.pmid {
                    MetadataBadge(text: "PMID: \(pmid)", color: .orange)
                    Text("(no DOI)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Download action row
            HStack {
                Spacer()
                switch result.downloadStatus {
                case .idle:
                    Button(action: onDownload) {
                        Label("Download PDF", systemImage: "arrow.down.circle.fill")
                            .font(.callout)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                case .downloading(let progress):
                    HStack(spacing: 10) {
                        ProgressView(value: progress)
                            .frame(width: 120)
                            .tint(.blue)
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(.blue)
                    }
                case .completed:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Downloaded")
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(.green)
                            if let source = store.paper(forDOI: result.doi)?.source {
                                Text("via \(source)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        // Category assignment
                        Button {
                            showCategoryPicker.toggle()
                        } label: {
                            Label(paperCategory.isEmpty ? "Set Category" : paperCategory,
                                  systemImage: "folder.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .popover(isPresented: $showCategoryPicker, arrowEdge: .bottom) {
                            categoryPickerPopover
                        }
                        Button {
                            let folder = UserDefaults.standard.string(forKey: AppConstants.downloadFolderKey)
                                ?? AppConstants.defaultDownloadFolder
                            NSWorkspace.shared.open(URL(fileURLWithPath: folder))
                        } label: {
                            Label("Open Folder", systemImage: "folder")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                case .failed(let message):
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Button("Retry", action: onDownload)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        Text("Tried: Unpaywall → PMC → Europe PMC → S2 → OpenAlex → Sci-Hub")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var paperCategory: String {
        store.paper(forDOI: result.doi)?.category ?? ""
    }

    private var categoryPickerPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assign Category")
                .font(.headline)

            if !store.categories.isEmpty {
                ForEach(store.categories, id: \.self) { cat in
                    Button {
                        assignCategory(cat)
                    } label: {
                        HStack {
                            Image(systemName: paperCategory == cat ? "folder.fill" : "folder")
                                .foregroundStyle(.orange)
                            Text(cat)
                            Spacer()
                            if paperCategory == cat {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Divider()
            }

            HStack(spacing: 4) {
                TextField("New category...", text: $newCategory)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit {
                        if !newCategory.trimmingCharacters(in: .whitespaces).isEmpty {
                            assignCategory(newCategory.trimmingCharacters(in: .whitespaces))
                            newCategory = ""
                        }
                    }
                Button {
                    let name = newCategory.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    assignCategory(name)
                    newCategory = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 220)
    }

    private func assignCategory(_ category: String) {
        if let paper = store.paper(forDOI: result.doi) {
            store.setCategory(category, for: paper)
        }
        showCategoryPicker = false
    }
}

struct MetadataBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
