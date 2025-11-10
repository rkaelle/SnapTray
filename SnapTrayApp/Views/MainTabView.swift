import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home/Scan Tab
            HomeView()
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }
                .tag(0)

            // Markers Tab
            MarkersView()
                .tabItem {
                    Label("Markers", systemImage: "qrcode")
                }
                .tag(1)

            // Projects Tab
            ProjectsView()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .tag(2)

            // Tutorial Tab
            TutorialView()
                .tabItem {
                    Label("Tutorial", systemImage: "book.fill")
                }
                .tag(3)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCapture = false
    @State private var currentProject: Project?
    @State private var navigationPath: [NavigationDestination] = []

    enum NavigationDestination: Hashable {
        case confirm(Project)
        case export(Project)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 30) {
                Spacer()

                // App Logo/Icon
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("SnapTray")
                    .font(.system(size: 42, weight: .bold))

                Text("LiDAR Tool Tray Generator")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Spacer()

                // Quick Stats
                if !appState.projects.isEmpty {
                    VStack(spacing: 12) {
                        HStack(spacing: 30) {
                            StatBox(title: "Projects", value: "\(appState.projects.count)")
                            StatBox(title: "Tools Scanned", value: "\(totalToolsScanned)")
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Main Action Button
                Button(action: startNewScan) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Start New Scan")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                // Quick Tips
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before scanning:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Place 4 fiducial markers at corners")
                            .font(.caption)
                    }

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Use black matte background")
                            .font(.caption)
                    }

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Ensure good diffuse lighting")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("SnapTray")
            .sheet(isPresented: $showingCapture) {
                ManualCaptureView(onCaptureDone: { project in
                    showingCapture = false
                    currentProject = project
                    navigationPath.append(.confirm(project))
                }, onCancel: {
                    showingCapture = false
                })
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .confirm(let project):
                    if let index = appState.projects.firstIndex(where: { $0.id == project.id }) {
                        ConfirmView(project: $appState.projects[index], onContinue: {
                            navigationPath.append(.export(appState.projects[index]))
                        }, onBack: {
                            navigationPath.removeLast()
                        })
                    }
                case .export(let project):
                    ExportView(project: project, onDone: {
                        navigationPath.removeAll()
                    })
                }
            }
        }
    }

    private func startNewScan() {
        let project = Project(name: "Tray \(Date().formatted(date: .numeric, time: .omitted))")
        appState.projects.append(project)
        currentProject = project
        showingCapture = true
    }

    private var totalToolsScanned: Int {
        appState.projects.reduce(0) { $0 + $1.tools.count }
    }
}

struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
