import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var projectViewModel = ProjectViewModel()
    @State private var taskViewModel = TaskViewModel()
    @State private var selectedTab = 0
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @Query private var tasks: [Task]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProjectsListView(viewModel: projectViewModel)
                .tabItem {
                    Label("Projets", systemImage: "folder")
                }
                .tag(0)
            
            TasksListView(viewModel: taskViewModel)
                .tabItem {
                    Label("Tâches", systemImage: "checkmark.circle")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Paramètres", systemImage: "gear")
                }
                .tag(2)
        }
        .onAppear {
            projectViewModel.projects = projects
            taskViewModel.tasks = tasks
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, Task.self], inMemory: true)
}
