import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingDeleteAlert = false
    @State private var projectToDelete: Project?
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            ZStack {
                if filteredProjects.isEmpty {
                    EmptyProjectsView(searchText: searchText)
                } else {
                    List {
                        ForEach(filteredProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: binding(for: project))) {
                                ProjectRow(project: project)
                            }
                        }
                        .onDelete(perform: deleteProjects)
                    }
                    .searchable(text: $searchText, prompt: "Search projects")
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !appState.projects.isEmpty {
                        EditButton()
                    }
                }
            }
            .alert("Delete Project", isPresented: $showingDeleteAlert, presenting: projectToDelete) { project in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let index = appState.projects.firstIndex(where: { $0.id == project.id }) {
                        appState.projects.remove(at: index)
                        appState.saveProjects()
                    }
                }
            } message: { project in
                Text("Are you sure you want to delete '\(project.name)'? This cannot be undone.")
            }
        }
    }

    private var filteredProjects: [Project] {
        if searchText.isEmpty {
            return appState.projects.sorted { $0.modifiedDate > $1.modifiedDate }
        } else {
            return appState.projects.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.modifiedDate > $1.modifiedDate }
        }
    }

    private func binding(for project: Project) -> Binding<Project> {
        guard let index = appState.projects.firstIndex(where: { $0.id == project.id }) else {
            fatalError("Project not found")
        }
        return $appState.projects[index]
    }

    private func deleteProjects(at offsets: IndexSet) {
        let projectsToDelete = offsets.map { filteredProjects[$0] }
        for project in projectsToDelete {
            if let index = appState.projects.firstIndex(where: { $0.id == project.id }) {
                appState.projects.remove(at: index)
            }
        }
        appState.saveProjects()
    }
}

struct EmptyProjectsView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "folder.badge.plus" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(searchText.isEmpty ? "No Projects Yet" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)

            Text(searchText.isEmpty ?
                 "Scan your first tool tray to get started" :
                 "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 15) {
            // Thumbnail or icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: "cube.box.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            // Project info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(project.tools.filter { $0.enabled }.count)", systemImage: "wrench.and.screwdriver.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label(project.modifiedDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ProjectDetailView: View {
    @Binding var project: Project
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showingExport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project image if available
                if let imageData = project.capturedImage,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12)
                        .padding()
                }

                // Project info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project Information")
                        .font(.headline)
                        .padding(.horizontal)

                    InfoRow(label: "Name", value: project.name)
                    InfoRow(label: "Created", value: project.createdDate.formatted(date: .long, time: .shortened))
                    InfoRow(label: "Modified", value: project.modifiedDate.formatted(date: .long, time: .shortened))
                    InfoRow(label: "Tools", value: "\(project.tools.filter { $0.enabled }.count) active")

                    if let scale = project.pixelToMMScale {
                        InfoRow(label: "Scale", value: String(format: "%.3f mm/pixel", scale))
                    }

                    if let bounds = project.workspaceBounds, let scale = project.pixelToMMScale {
                        let widthMM = bounds.width * scale
                        let heightMM = bounds.height * scale
                        InfoRow(label: "Workspace", value: String(format: "%.0f × %.0f mm", widthMM, heightMM))
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Tools list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tools (\(project.tools.filter { $0.enabled }.count))")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(project.tools.filter { $0.enabled }) { tool in
                        ToolSummaryRow(tool: tool, scale: project.pixelToMMScale ?? 1.0)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Actions
                Button(action: { showingExport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Files")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExport) {
            NavigationView {
                ExportView(project: project, onDone: {
                    showingExport = false
                })
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.horizontal)
    }
}

struct ToolSummaryRow: View {
    let tool: Tool
    let scale: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tool.label.isEmpty ? "Tool" : tool.label)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 10) {
                    Label(String(format: "%.1f mm", tool.effectiveDepth), systemImage: "arrow.down.to.line")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    let widthMM = tool.boundingBox.width * scale
                    let heightMM = tool.boundingBox.height * scale
                    Label(String(format: "%.0f×%.0f mm", widthMM, heightMM), systemImage: "ruler")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if tool.hasFingerNotch {
                Image(systemName: "hand.point.up.left.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
