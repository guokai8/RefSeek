import SwiftUI
import UniformTypeIdentifiers

struct ExportBibTeXSheet: View {
    let papers: [Paper]
    @Environment(\.dismiss) private var dismiss
    @State private var bibContent = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Export BibTeX")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(papers.count) papers")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(bibContent)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 300)
            .background(Color(nsColor: .textBackgroundColor))
            .border(Color.secondary.opacity(0.2))

            HStack {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bibContent, forType: .string)
                }
                .buttonStyle(.bordered)

                Button("Save as .bib File...") {
                    saveBibFile()
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
        .onAppear {
            bibContent = BibTeXFormatter.formatAll(papers)
        }
    }

    private func saveBibFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "bib") ?? .plainText]
        panel.nameFieldStringValue = "refseek_library.bib"

        if panel.runModal() == .OK, let url = panel.url {
            try? bibContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
