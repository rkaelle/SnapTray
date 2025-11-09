import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewProject = false
    @State private var currentScreen: AppScreen = .welcome

    enum AppScreen {
        case welcome
        case capture
        case confirm
        case export
    }

    var body: some View {
        NavigationView {
            ZStack {
                switch currentScreen {
                case .welcome:
                    WelcomeView(onStartCapture: {
                        appState.currentProject = Project(name: "New Tray")
                        currentScreen = .capture
                    })

                case .capture:
                    CaptureView(onCaptureDone: { project in
                        appState.currentProject = project
                        currentScreen = .confirm
                    }, onCancel: {
                        currentScreen = .welcome
                    })

                case .confirm:
                    if let project = appState.currentProject {
                        ConfirmView(project: .constant(project), onContinue: {
                            currentScreen = .export
                        }, onBack: {
                            currentScreen = .capture
                        })
                    }

                case .export:
                    if let project = appState.currentProject {
                        ExportView(project: project, onDone: {
                            currentScreen = .welcome
                        })
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct WelcomeView: View {
    let onStartCapture: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "cube.box.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("SnapTray")
                .font(.system(size: 42, weight: .bold))

            Text("LiDAR Tool Tray Generator")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "camera.fill", text: "Scan tools with LiDAR")
                FeatureRow(icon: "square.grid.3x3.fill", text: "Auto-detect tool outlines")
                FeatureRow(icon: "cube.fill", text: "Generate 3D-printable trays")
                FeatureRow(icon: "doc.fill", text: "Export DXF, STL, and PDF")
            }
            .padding()

            Spacer()

            Button(action: onStartCapture) {
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

            Text("Make sure you have 4 fiducial markers ready")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)

            Text(text)
                .font(.body)
        }
    }
}
