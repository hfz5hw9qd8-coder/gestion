import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("À propos") {
                    HStack {
                        Text("Gestion des tâches")
                        Spacer()
                        Text("v1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Développé par")
                        Spacer()
                        Text("Mathieu")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Interface") {
                    NavigationLink(destination: EmptyView()) {
                        Text("Thème")
                    }
                    
                    NavigationLink(destination: EmptyView()) {
                        Text("Apparence")
                    }
                }
            }
            .navigationTitle("Paramètres")
        }
    }
}

#Preview {
    SettingsView()
}
