import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("defaultMaterial") private var defaultMaterial = MaterialType.pla.rawValue
    @AppStorage("defaultTrayThickness") private var defaultTrayThickness = 12.0
    @AppStorage("defaultEdgeMargin") private var defaultEdgeMargin = 10.0
    @AppStorage("autoSaveProjects") private var autoSaveProjects = true
    @AppStorage("showScanGuide") private var showScanGuide = true
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("measurementUnit") private var measurementUnit = "metric"

    var body: some View {
        NavigationView {
            Form {
                // App Information
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SnapTray")
                                .font(.headline)
                            Text("LiDAR Tool Tray Generator")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("v1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Default Tray Settings
                Section("Default Tray Settings") {
                    Picker("Material", selection: $defaultMaterial) {
                        ForEach(MaterialType.allCases, id: \.rawValue) { material in
                            Text(material.displayName).tag(material.rawValue)
                        }
                    }

                    HStack {
                        Text("Tray Thickness")
                        Spacer()
                        Text("\(Int(defaultTrayThickness)) mm")
                            .foregroundColor(.secondary)
                    }

                    Stepper("", value: $defaultTrayThickness, in: 6...25, step: 1)
                        .labelsHidden()

                    HStack {
                        Text("Edge Margin")
                        Spacer()
                        Text("\(Int(defaultEdgeMargin)) mm")
                            .foregroundColor(.secondary)
                    }

                    Stepper("", value: $defaultEdgeMargin, in: 5...25, step: 1)
                        .labelsHidden()
                }

                // Scanning Options
                Section("Scanning") {
                    Toggle("Show Scan Guide", isOn: $showScanGuide)
                    Toggle("Auto-Save Projects", isOn: $autoSaveProjects)
                }

                // App Behavior
                Section("App Behavior") {
                    Toggle("Haptic Feedback", isOn: $enableHaptics)

                    Picker("Units", selection: $measurementUnit) {
                        Text("Metric (mm)").tag("metric")
                        Text("Imperial (inches)").tag("imperial")
                    }
                }

                // Material Presets
                Section("Material Presets") {
                    NavigationLink(destination: MaterialPresetsView()) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Manage Presets")
                        }
                    }
                }

                // Storage & Data
                Section("Storage") {
                    HStack {
                        Text("Projects Saved")
                        Spacer()
                        Text("\(appState.projects.count)")
                            .foregroundColor(.secondary)
                    }

                    Button(action: clearCache) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Cache")
                        }
                        .foregroundColor(.red)
                    }

                    Button(action: exportAllProjects) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export All Projects")
                        }
                    }
                }

                // Help & Support
                Section("Help & Support") {
                    Link(destination: URL(string: "https://github.com/yourusername/SnapTray")!) {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/yourusername/SnapTray/issues")!) {
                        HStack {
                            Image(systemName: "exclamationmark.bubble.fill")
                            Text("Report Issue")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                        }
                    }

                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                            Text("About")
                        }
                    }
                }

                // Advanced
                Section("Advanced") {
                    NavigationLink(destination: AdvancedSettingsView()) {
                        HStack {
                            Image(systemName: "gearshape.2.fill")
                            Text("Advanced Settings")
                        }
                    }

                    Button(action: resetAllSettings) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Settings")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func clearCache() {
        // Clear temporary files, cached images, etc.
        // Show confirmation alert
    }

    private func exportAllProjects() {
        // Export all projects as a bundle
    }

    private func resetAllSettings() {
        // Reset to defaults
        defaultMaterial = MaterialType.pla.rawValue
        defaultTrayThickness = 12.0
        defaultEdgeMargin = 10.0
        autoSaveProjects = true
        showScanGuide = true
        enableHaptics = true
        measurementUnit = "metric"
    }
}

struct MaterialPresetsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            ForEach(appState.materialPresets) { preset in
                VStack(alignment: .leading, spacing: 8) {
                    Text(preset.name)
                        .font(.headline)

                    HStack(spacing: 15) {
                        Label("XY: \(String(format: "%.2f", preset.xyInterference))mm", systemImage: "arrow.left.and.right")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Z: \(String(format: "%.2f", preset.zOffset))mm", systemImage: "arrow.up.and.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Material Presets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                VStack(spacing: 8) {
                    Text("SnapTray")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Version 1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 15) {
                    Text("About")
                        .font(.headline)

                    Text("SnapTray uses LiDAR technology to scan your tools and automatically generate custom 3D-printable trays. Perfect for organizing drawers, toolboxes, and workspaces.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 15) {
                    Text("Features")
                        .font(.headline)

                    FeatureItem(icon: "camera.fill", text: "LiDAR scanning for precise measurements")
                    FeatureItem(icon: "cube.fill", text: "Automatic tool detection and segmentation")
                    FeatureItem(icon: "square.grid.3x3.fill", text: "Smart geometry processing")
                    FeatureItem(icon: "doc.fill", text: "Export to DXF, STL, and PDF")
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 15) {
                    Text("Requirements")
                        .font(.headline)

                    Text("• iPhone 12 Pro or later (with LiDAR sensor)\n• iOS 15.0 or later\n• 3D printer or foam cutting access")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 10) {
                    Text("Made with ❤️ for makers")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("© 2024 SnapTray")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("lidarSamplingRate") private var lidarSamplingRate = 4.0
    @AppStorage("planeDetectionThreshold") private var planeDetectionThreshold = 10.0
    @AppStorage("contourSimplification") private var contourSimplification = 2.0
    @AppStorage("minToolArea") private var minToolArea = 200.0

    var body: some View {
        Form {
            Section("LiDAR Processing") {
                HStack {
                    Text("Sampling Rate")
                    Spacer()
                    Text("\(Int(lidarSamplingRate))px")
                        .foregroundColor(.secondary)
                }

                Slider(value: $lidarSamplingRate, in: 2...8, step: 1)

                Text("Higher = faster but less accurate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Plane Detection") {
                HStack {
                    Text("Threshold")
                    Spacer()
                    Text("\(Int(planeDetectionThreshold))mm")
                        .foregroundColor(.secondary)
                }

                Slider(value: $planeDetectionThreshold, in: 5...20, step: 1)

                Text("Sensitivity for detecting flat surfaces")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Tool Detection") {
                HStack {
                    Text("Contour Simplification")
                    Spacer()
                    Text("\(String(format: "%.1f", contourSimplification))mm")
                        .foregroundColor(.secondary)
                }

                Slider(value: $contourSimplification, in: 0.5...5.0, step: 0.5)

                Text("Higher = smoother but less detail")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Minimum Tool Area")
                    Spacer()
                    Text("\(Int(minToolArea))mm²")
                        .foregroundColor(.secondary)
                }

                Slider(value: $minToolArea, in: 100...500, step: 50)

                Text("Filters out small noise/debris")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Button("Reset to Defaults") {
                    lidarSamplingRate = 4.0
                    planeDetectionThreshold = 10.0
                    contourSimplification = 2.0
                    minToolArea = 200.0
                }
            }
        }
        .navigationTitle("Advanced Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
