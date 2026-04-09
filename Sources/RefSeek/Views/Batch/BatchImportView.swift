import SwiftUI
import UniformTypeIdentifiers

struct BatchImportView: View {
    @EnvironmentObject private var store: PaperStore
    @StateObject private var viewModel = BatchViewModel()
    @State private var inputText = ""
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            // Input area
            VStack(alignment: .leading, spacing: 8) {
                Text("Paste DOIs or titles (one per line), drag a file here, or import:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120, maxHeight: 200)
                    .border(isDragOver ? Color.accentColor : Color.secondary.opacity(0.2), width: isDragOver ? 2 : 1)
                    .onDrop(of: [.fileURL, .plainText], isTargeted: $isDragOver) { providers in
                        handleDrop(providers)
                    }

                HStack {
                    Button("Import from File...") {
                        importFile()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text("\(inputLineCount) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Start Batch Download") {
                        let items = parseInput()
                        Task { await viewModel.startBatch(items: items, store: store) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)
                }
            }
            .padding()
            .background(.bar)

            Divider()

            // Progress list
            if viewModel.batchItems.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Batch Download")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Paste multiple DOIs or paper titles above,\nor import from a .txt / .csv file.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        BatchHintRow(icon: "doc.plaintext", text: "One DOI or title per line")
                        BatchHintRow(icon: "arrow.down.doc", text: "Import from .txt or .csv file")
                        BatchHintRow(icon: "hand.draw", text: "Drag & drop .txt/.csv files into the text area")
                        BatchHintRow(icon: "speedometer", text: "Downloads run concurrently (configurable)")
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
                    Spacer()
                }
                .padding()
            } else {
                List {
                    ForEach(viewModel.batchItems) { item in
                        BatchItemRow(item: item)
                    }
                }
                .listStyle(.inset)

                // Summary bar
                HStack(spacing: 16) {
                    let completed = viewModel.batchItems.filter { $0.status == .completed }.count
                    let failed = viewModel.batchItems.filter { if case .failed = $0.status { return true }; return false }.count
                    let total = viewModel.batchItems.count

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(completed)/\(total)")
                            .fontWeight(.medium)
                    }
                    .font(.callout)

                    if failed > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(failed) failed")
                        }
                        .font(.callout)
                    }

                    if viewModel.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    if viewModel.isRunning {
                        Button("Cancel All") {
                            viewModel.cancelAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .navigationTitle("Batch Download")
    }

    private var inputLineCount: Int {
        inputText.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }

    private func parseInput() -> [String] {
        inputText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Handle file URLs
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        if let content = try? String(contentsOf: url, encoding: .utf8) {
                            DispatchQueue.main.async {
                                if inputText.isEmpty {
                                    inputText = content
                                } else {
                                    inputText += "\n" + content
                                }
                            }
                        }
                    }
                }
                return true
            }
            // Handle plain text
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    if let text = item as? String {
                        DispatchQueue.main.async {
                            if inputText.isEmpty {
                                inputText = text
                            } else {
                                inputText += "\n" + text
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                inputText = content
            }
        }
    }
}

struct BatchItemRow: View {
    let item: BatchItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? item.query)
                    .font(.callout)
                    .lineLimit(1)
                if let doi = item.doi {
                    Text(doi)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            switch item.status {
            case .pending:
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .resolving:
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("Resolving DOI...")
                        .font(.caption)
                }
            case .downloading(let progress):
                HStack(spacing: 4) {
                    ProgressView(value: progress)
                        .frame(width: 80)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                }
            case .completed:
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failed(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct BatchHintRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
