import Foundation
import SwiftData

@Model
final class Project {
    var name: String
    var taskDescription: String
    var color: String
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Task.project) var tasks: [Task] = []
    
    init(
        name: String,
        taskDescription: String = "",
        color: String = "blue"
    ) {
        self.name = name
        self.taskDescription = taskDescription
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.isCompleted }.count) / Double(tasks.count)
    }
}
