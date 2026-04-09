import Foundation

class BatchItem: Identifiable, ObservableObject {
    let id = UUID()
    let query: String
    var doi: String?
    var title: String?
    @Published var status: BatchItemStatus = .pending

    init(query: String) {
        self.query = query
        if DOIParser.isDOI(query) {
            self.doi = DOIParser.extractDOI(from: query)
        }
    }
}

enum BatchItemStatus: Equatable {
    case pending
    case resolving
    case downloading(Double)
    case completed
    case failed(String)
}
