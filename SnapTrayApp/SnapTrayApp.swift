import SwiftUI

@main
struct SnapTrayApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var currentProject: Project?
    @Published var materialPresets: [MaterialPreset]
    @Published var userTolerances: [String: ToleranceSettings] = [:]

    init() {
        // Initialize default material presets
        self.materialPresets = MaterialPreset.defaults

        // Load user preferences
        loadUserPreferences()
    }

    func loadUserPreferences() {
        if let data = UserDefaults.standard.data(forKey: "userTolerances"),
           let tolerances = try? JSONDecoder().decode([String: ToleranceSettings].self, from: data) {
            self.userTolerances = tolerances
        }
    }

    func saveUserPreferences() {
        if let data = try? JSONEncoder().encode(userTolerances) {
            UserDefaults.standard.set(data, forKey: "userTolerances")
        }
    }
}
