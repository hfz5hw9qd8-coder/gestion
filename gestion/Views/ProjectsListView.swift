import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @ObservedRealmObject var viewModel: ProjectViewModel
    @State private var showAddProject = false
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $viewModel.searchText)
                
                if viewModel.filteredAndSortedProjects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Aucun projet")
                            .font(.headline)
                        Text("Créez votre premier projet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.filteredAndSortedProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRow(project: project)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddProject = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddProject) {
                AddProjectView(modelContext: modelContext)
            }
        }
    }
}

struct ProjectRow: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(project.color))
                    .frame(width: 12, height: 12)
                
                Text(project.name)
                    .font(.headline)
                
                Spacer()
                
                Text("\(project.tasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: project.progress)
                .tint(Color(project.color))
            
            Text(project.taskDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Rechercher...", text: $text)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

#Preview {
    ProjectsListView(viewModel: ProjectViewModel())
        .modelContainer(for: [Project.self, Task.self], inMemory: true)
}
