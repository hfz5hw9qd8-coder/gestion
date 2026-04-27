import Foundation
import SwiftData

@Observable
class TaskViewModel {
    var tasks: [Task] = []
    var searchText: String = ""
    var sortBy: SortOption = .date
    
    enum SortOption: String, CaseIterable {
        case date = "Date"
        case priority = "Priorité"
        case name = "Nom"
        case creation = "Création"
    }
    
    func addTask(_ task: Task, modelContext: ModelContext) {
        modelContext.insert(task)
        try? modelContext.save()
    }
    
    func updateTask(_ task: Task, modelContext: ModelContext) {
        task.updatedAt = Date()
        try? modelContext.save()
    }
    
    func deleteTask(_ task: Task, modelContext: ModelContext) {
        modelContext.delete(task)
        try? modelContext.save()
    }
    
    func toggleComplete(_ task: Task, modelContext: ModelContext) {
        task.isCompleted.toggle()
        task.updatedAt = Date()
        try? modelContext.save()
    }
    
    var filteredAndSortedTasks: [Task] {
        var filtered = tasks.filter { task in
            searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText)
        }
        
        switch sortBy {
        case .date:
            return filtered.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
        case .priority:
            let priorityOrder: [Priority] = [.critical, .high, .medium, .low]
            return filtered.sorted { a, b in
                (priorityOrder.firstIndex(of: a.priority) ?? 0) < (priorityOrder.firstIndex(of: b.priority) ?? 0)
            }
        case .name:
            return filtered.sorted { $0.title < $1.title }
        case .creation:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    var groupedTasks: [(category: String, tasks: [Task])] {
        var groups: [String: [Task]] = [:]
        
        for task in filteredAndSortedTasks {
            let category: String
            
            if task.isCompleted {
                category = "✓ Complétées"
            } else if let dueDate = task.dueDate, Calendar.current.isDateInPast(dueDate, granularity: .day) {
                category = "⚠ En retard"
            } else if let dueDate = task.dueDate, Calendar.current.isDateInToday(dueDate) {
                category = "📅 Aujourd'hui"
            } else if let dueDate = task.dueDate, Calendar.current.isDateInTomorrow(dueDate) {
                category = "📆 Demain"
            } else {
                category = "📌 Prochainement"
            }
            
            groups[category, default: []].append(task)
        }
        
        return groups.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
}
