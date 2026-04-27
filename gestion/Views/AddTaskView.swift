import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var priority: Priority = .medium
    @State private var dueDate: Date?
    @State private var showDatePicker = false
    @Query private var projects: [Project]
    @State private var selectedProject: Project?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Infos de la tâche") {
                    TextField("Titre", text: $title)
                    TextField("Description", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...)
                }
                
                Section("Détails") {
                    Picker("Priorité", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: "exclamationmark.circle.fill")
                                .tag(p)
                        }
                    }
                    
                    Picker("Projet", selection: $selectedProject) {
                        Text("Aucun").tag(nil as Project?)
                        ForEach(projects) { project in
                            HStack {
                                Circle().fill(Color(project.color)).frame(width: 8, height: 8)
                                Text(project.name)
                            }
                            .tag(project as Project?)
                        }
                    }
                }
                
                Section("Date d'échéance") {
                    if let dueDate = dueDate {
                        HStack {
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Button(role: .destructive) { self.dueDate = nil } label: {
                                Text("Supprimer")
                            }
                        }
                    } else {
                        Button(action: { showDatePicker.toggle() }) {
                            Text("Ajouter une date")
                        }
                    }
                }
            }
            .navigationTitle("Nouvelle tâche")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { addTask() }
                        .disabled(title.isEmpty)
                }
            }
            .popover(isPresented: $showDatePicker) {
                DatePicker("Date", selection: Binding(
                    get: { dueDate ?? Date() },
                    set: { dueDate = $0 }
                ), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
            }
        }
    }
    
    private func addTask() {
        let task = Task(title: title, taskDescription: taskDescription, priority: priority, dueDate: dueDate, project: selectedProject)
        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddTaskView()
        .modelContainer(for: [Project.self, Task.self], inMemory: true)
}
