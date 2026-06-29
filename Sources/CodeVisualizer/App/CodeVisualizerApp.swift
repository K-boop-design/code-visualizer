import SwiftUI

@main
struct CodeVisualizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @AppStorage("pythonPath") private var pythonPath: String = ""
    @AppStorage("defaultMode") private var defaultMode: String = "full"

    var body: some View {
        TabView {
            Form {
                TextField("Python Path", text: $pythonPath)
                    .textFieldStyle(.roundedBorder)
                Text("Leave empty to use system Python")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .tabItem {
                Label("Python", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Form {
                Picker("Default Mode", selection: $defaultMode) {
                    Text("Full (Flowchart + Pipeline)").tag("full")
                    Text("Flowchart Only").tag("flowchart")
                    Text("Pipeline Only").tag("pipeline")
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 400, height: 200)
    }
}
