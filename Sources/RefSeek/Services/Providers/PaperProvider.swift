import Foundation

/// Protocol for paper PDF providers
protocol PaperProvider {
    var name: String { get }
    /// Attempt to get a direct PDF download URL for the given DOI
    func pdfURL(for doi: String) async throws -> URL?
}

enum RefSeekError: LocalizedError {
    case invalidInput(String)
    case networkError(String)
    case noPDFFound(String)
    case invalidPDF
    case downloadFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .noPDFFound(let msg): return "No PDF found: \(msg)"
        case .invalidPDF: return "Downloaded file is not a valid PDF"
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .cancelled: return "Operation cancelled"
        }
    }
}
