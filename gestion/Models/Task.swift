import Foundation
import SwiftData

@Model
final class Task {
    var title: String
    var taskDescription: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var project: Project?
    
    init(
        title: String,
        taskDescription: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        project: Project? = nil
    ) {
        self.title = title
        self.taskDescription = taskDescription
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.project = project
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
