import Foundation
import SwiftData

@Model
final class Task {
    var title: String
    var description: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil
    ) {
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum Priority: String, Codable, CaseIterable {
    case low = "Basse"
    case medium = "Moyenne"
    case high = "Haute"
    case critical = "Critique"
    
    var color: String {
        switch self {
        case .low:
            return "green"
        case .medium:
            return "yellow"
        case .high:
            return "orange"
        case .critical:
            return "red"
        }
    }
}
