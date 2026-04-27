import SwiftUI
import SwiftData

struct AddProjectView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var taskDescription = ""
    @State private var selectedColor = "blue"
    
    let colors = ["blue", "red", "green", "orange", "yellow", "purple", "pink"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Infos du projet") {
                    TextField("Nom", text: $name)
                    TextField("Description", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...)
                }
                
                Section("Couleur") {
                    HStack(spacing: 16) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(Color(color))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }
            }
            .navigationTitle("Nouveau projet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { addProject() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func addProject() {
        let project = Project(name: name, taskDescription: taskDescription, color: selectedColor)
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddProjectView()
        .modelContainer(for: [Project.self, Task.self], inMemory: true)
}
