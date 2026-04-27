import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var showEdit = false
    @State private var editName = ""
    @State private var editDescription = ""
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color(project.color))
                        .frame(width: 16, height: 16)
                    
                    Text(project.name)
                        .font(.title2.bold())
                    
                    Spacer()
                    
                    Button(action: { showEdit = true }) {
                        Image(systemName: "pencil")
                    }
                }
                
                if !project.taskDescription.isEmpty {
                    Text(project.taskDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(project.tasks.filter { $0.isCompleted }.count) / \(project.tasks.count) complétées")
                            .font(.caption.bold())
                        Spacer()
                        Text(String(format: "%.0f%%", project.progress * 100))
                            .font(.caption.bold())
                    }
                    
                    ProgressView(value: project.progress)
                        .tint(Color(project.color))
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            List {
                ForEach(project.tasks) { task in
                    TaskRow(task: task, viewModel: TaskViewModel())
                }
                .onDelete { indices in
                    for index in indices {
                        modelContext.delete(project.tasks[index])
                    }
                    try? modelContext.save()
                }
            }
            
            Spacer()
        }
        .navigationTitle("Détail du projet")
        .sheet(isPresented: $showEdit) {
            EditProjectView(project: project)
        }
    }
}

struct EditProjectView: View {
    let project: Project
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var taskDescription = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Infos du projet") {
                    TextField("Nom", text: $name)
                    TextField("Description", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...)
                }
            }
            .navigationTitle("Modifier le projet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { saveChanges() }
                }
            }
        }
        .onAppear {
            name = project.name
            taskDescription = project.taskDescription
        }
    }
    
    private func saveChanges() {
        project.name = name
        project.taskDescription = taskDescription
        project.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ProjectDetailView(project: Project(name: "Test"))
        .modelContainer(for: [Project.self, Task.self], inMemory: true)
}
