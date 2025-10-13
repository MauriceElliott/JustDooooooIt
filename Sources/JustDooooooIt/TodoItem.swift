import Foundation

struct TodoItem: Codable {
    let id: UInt32
    let text: String
    var completed: Bool
    let parentId: UInt32?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case completed
        case parentId = "parent_id"
        case createdAt = "created_at"
    }
}