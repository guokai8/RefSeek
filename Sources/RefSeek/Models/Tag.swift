import Foundation

struct Tag: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var color: String

    init(name: String, color: String = "blue") {
        self.name = name
        self.color = color
    }
}
