import SwiftUI

struct SearchResultRow: View {
    let result: SearchResult
    let onDownload: () -> Void

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
                        Text("Downloaded")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                case .failed(let message):
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Button("Retry", action: onDownload)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 8)
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
