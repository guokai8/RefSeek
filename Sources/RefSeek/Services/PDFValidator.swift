import Foundation

enum PDFValidator {
    /// Check if data starts with PDF magic bytes (%PDF)
    static func isValidPDF(data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let magic = AppConstants.pdfMagicBytes
        return data.prefix(4).elementsEqual(magic)
    }

    /// Check if a file at the given path is a valid PDF
    static func isValidPDF(at path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path) else { return false }
        return isValidPDF(data: data)
    }
}
