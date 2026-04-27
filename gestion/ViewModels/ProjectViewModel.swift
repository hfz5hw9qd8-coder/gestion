import Foundation
import SwiftData

@Observable
class ProjectViewModel {
    var projects: [Project] = []
    var searchText: String = ""
    var sortBy: SortOption = .updated
    
    enum SortOption: String, CaseIterable {
        case updated = "Modifié"
        case name = "Nom"
        case creation = "Création"
    }
    
    func addProject(_ project: Project, modelContext: ModelContext) {
        modelContext.insert(project)
        try? modelContext.save()
    }
    
    func updateProject(_ project: Project, modelContext: ModelContext) {
        project.updatedAt = Date()
        try? modelContext.save()
    }
    
    func deleteProject(_ project: Project, modelContext: ModelContext) {
        modelContext.delete(project)
        try? modelContext.save()
    }
    
    var filteredAndSortedProjects: [Project] {
        var filtered = projects.filter { project in
            searchText.isEmpty || project.name.localizedCaseInsensitiveContains(searchText) ||
            project.taskDescription.localizedCaseInsensitiveContains(searchText)
        }
        
        switch sortBy {
        case .updated:
            return filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .name:
            return filtered.sorted { $0.name < $1.name }
        case .creation:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }
}
