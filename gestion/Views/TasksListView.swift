import SwiftUI
import SwiftData

struct TasksListView: View {
    @ObservedRealmObject var viewModel: TaskViewModel
    @State private var showAddTask = false
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [Task]
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $viewModel.searchText)
                
                if viewModel.groupedTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Aucune tâche")
                            .font(.headline)
                        Text("Créez votre première tâche")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.groupedTasks, id: \.category) { group in
                            Section(header: Text(group.category)) {
                                ForEach(group.tasks) { task in
                                    TaskRow(task: task, viewModel: viewModel)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tâches")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(modelContext: modelContext)
            }
        }
    }
}

struct TaskRow: View {
    let task: Task
    let viewModel: TaskViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.toggleComplete(task, modelContext: modelContext) }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.isCompleted)
                    
                    Spacer()
                    
                    Label(task.priority.rawValue, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(Color(task.priority.color))
                }
                
                if let dueDate = task.dueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    TasksListView(viewModel: TaskViewModel())
        .modelContainer(for: [Project.self, Task.self], inMemory: true)
}
