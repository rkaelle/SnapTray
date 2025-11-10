import SwiftUI

@main
struct SnapTrayApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .onAppear {
                    appState.loadProjects()
                }
        }
    }
}

class AppState: ObservableObject {
    @Published var currentProject: Project?
    @Published var projects: [Project] = []
    @Published var materialPresets: [MaterialPreset]
    @Published var userTolerances: [String: ToleranceSettings] = [:]

    private let projectsKey = "savedProjects"

    init() {
        // Initialize default material presets
        self.materialPresets = MaterialPreset.defaults

        // Load user preferences
        loadUserPreferences()
        loadProjects()
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

    func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: projectsKey),
           let loadedProjects = try? JSONDecoder().decode([Project].self, from: data) {
            self.projects = loadedProjects
        }
    }

    func saveProjects() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: projectsKey)
        }
    }

    func addProject(_ project: Project) {
        projects.append(project)
        saveProjects()
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            saveProjects()
        }
    }

    func deleteProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects.remove(at: index)
            saveProjects()
        }
    }
}
