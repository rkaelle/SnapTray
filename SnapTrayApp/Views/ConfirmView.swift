import SwiftUI

struct ConfirmView: View {
    @Binding var project: Project
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var selectedToolIndex: Int?
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }

                Spacer()

                Text("Review Tools")
                    .font(.headline)

                Spacer()

                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(radius: 2)

            // Preview area
            ScrollView {
                VStack(spacing: 20) {
                    // Summary card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Scan Summary")
                                .font(.headline)
                        }

                        Divider()

                        SummaryRow(label: "Tools detected", value: "\(project.tools.filter { $0.enabled }.count)")
                        SummaryRow(label: "Material", value: project.traySettings.material.displayName)
                        SummaryRow(label: "Tray thickness", value: String(format: "%.1f mm", project.traySettings.trayThickness))

                        if let scale = project.pixelToMMScale, let bounds = project.workspaceBounds {
                            let widthMM = bounds.width * scale
                            let heightMM = bounds.height * scale
                            SummaryRow(label: "Workspace", value: String(format: "%.0f × %.0f mm", widthMM, heightMM))
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Tool list
                    VStack(spacing: 12) {
                        ForEach(Array(project.tools.enumerated()), id: \.element.id) { index, tool in
                            ToolCard(
                                tool: tool,
                                index: index,
                                scale: project.pixelToMMScale ?? 1.0,
                                isSelected: selectedToolIndex == index,
                                onTap: {
                                    selectedToolIndex = index
                                },
                                onToggle: {
                                    project.tools[index].enabled.toggle()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Tray preview image
                    if let imageData = project.capturedImage,
                       let image = UIImage(data: imageData) {
                        VStack(alignment: .leading) {
                            Text("Captured Scan")
                                .font(.headline)
                                .padding(.horizontal)

                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }

                    // Depth map visualization
                    if let depthData = project.depthMap,
                       let depthImage = UIImage(data: depthData) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Depth Map")
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 8) {
                                    // Legend
                                    DepthLegend()
                                }
                            }
                            .padding(.horizontal)

                            Image(uiImage: depthImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                                .padding(.horizontal)

                            Text("Color represents height above plane: Blue (low) → Green → Yellow → Red (high)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }

            // Bottom actions
            HStack(spacing: 15) {
                Button(action: { showingSettings = true }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Tray Settings")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                }

                Button(action: onContinue) {
                    HStack {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(radius: 2)
        }
        .sheet(isPresented: $showingSettings) {
            TraySettingsView(project: $project)
        }
        .sheet(item: Binding(
            get: { selectedToolIndex.map { ToolSelection(index: $0) } },
            set: { selectedToolIndex = $0?.index }
        )) { selection in
            ToolDetailView(tool: $project.tools[selection.index], scale: project.pixelToMMScale ?? 1.0)
        }
    }
}

struct ToolSelection: Identifiable {
    let id = UUID()
    let index: Int
}

struct SummaryRow: View {
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
    }
}

struct ToolCard: View {
    let tool: Tool
    let index: Int
    let scale: Double
    let isSelected: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: tool.enabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(tool.enabled ? .blue : .gray)
            }

            // Tool info
            VStack(alignment: .leading, spacing: 4) {
                Text(tool.label.isEmpty ? "Tool \(index + 1)" : tool.label)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(
                        String(format: "%.1f mm", tool.effectiveDepth),
                        systemImage: "arrow.down.to.line"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)

                    let areaMM = tool.area * scale * scale
                    Label(
                        String(format: "%.0f mm²", areaMM),
                        systemImage: "square"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                if tool.hasFingerNotch {
                    Label("Finger notch", systemImage: "hand.point.up.left.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Detail button
            Button(action: onTap) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

struct ToolDetailView: View {
    @Binding var tool: Tool
    let scale: Double

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Tool Information") {
                    TextField("Label", text: $tool.label)

                    HStack {
                        Text("Enabled")
                        Spacer()
                        Toggle("", isOn: $tool.enabled)
                    }
                }

                Section("Measurements") {
                    let widthMM = tool.boundingBox.width * scale
                    let heightMM = tool.boundingBox.height * scale
                    let areaMM = tool.area * scale * scale

                    LabeledContent("Width", value: String(format: "%.1f mm", widthMM))
                    LabeledContent("Height", value: String(format: "%.1f mm", heightMM))
                    LabeledContent("Area", value: String(format: "%.0f mm²", areaMM))

                    HStack {
                        Text("Depth")
                        Spacer()
                        Text(String(format: "%.1f mm", tool.maxDepth))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Depth Override")
                        Spacer()
                        if let override = tool.depthOverride {
                            Text(String(format: "%.1f mm", override))
                        } else {
                            Text("Auto")
                                .foregroundColor(.secondary)
                        }
                    }

                    Stepper(
                        value: Binding(
                            get: { tool.depthOverride ?? tool.maxDepth },
                            set: { tool.depthOverride = $0 }
                        ),
                        in: 1...50,
                        step: 0.5
                    ) {
                        Text("Adjust Depth")
                    }

                    Button("Reset to Auto") {
                        tool.depthOverride = nil
                    }
                    .disabled(tool.depthOverride == nil)
                }

                Section("Finger Notch") {
                    Toggle("Add finger notch", isOn: $tool.hasFingerNotch)

                    if tool.hasFingerNotch, let notch = tool.fingerNotch {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text(String(format: "%.1f mm", notch.radius))
                                .foregroundColor(.secondary)
                        }

                        Stepper(
                            value: Binding(
                                get: { notch.radius },
                                set: {
                                    var updated = notch
                                    updated.radius = $0
                                    tool.fingerNotch = updated
                                }
                            ),
                            in: 4...15,
                            step: 0.5
                        ) {
                            Text("Adjust Radius")
                        }
                    }
                }

                Section("Contour") {
                    LabeledContent("Points", value: "\(tool.contour.count)")
                    LabeledContent("Simplified", value: "\(tool.simplifiedContour.count)")
                    LabeledContent("After Offset", value: "\(tool.offsetContour.count)")
                }
            }
            .navigationTitle("Tool Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct TraySettingsView: View {
    @Binding var project: Project

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Project") {
                    TextField("Project Name", text: $project.name)
                }

                Section("Material") {
                    Picker("Material Type", selection: $project.traySettings.material) {
                        ForEach(MaterialType.allCases, id: \.self) { material in
                            Text(material.displayName).tag(material)
                        }
                    }

                    HStack {
                        Text("XY Interference")
                        Spacer()
                        Text(String(format: "%.2f mm", project.traySettings.xyInterference))
                            .foregroundColor(.secondary)
                    }

                    Stepper(
                        value: $project.traySettings.xyInterference,
                        in: -1.0...1.0,
                        step: 0.05
                    ) {
                        Text("Adjust Interference")
                    }

                    Text("Negative = tighter fit, Positive = looser fit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Tray Dimensions") {
                    HStack {
                        Text("Thickness")
                        Spacer()
                        Text(String(format: "%.1f mm", project.traySettings.trayThickness))
                            .foregroundColor(.secondary)
                    }

                    Stepper(
                        value: $project.traySettings.trayThickness,
                        in: 6...25,
                        step: 1
                    ) {
                        Text("Adjust Thickness")
                    }

                    HStack {
                        Text("Edge Margin")
                        Spacer()
                        Text(String(format: "%.1f mm", project.traySettings.edgeMargin))
                            .foregroundColor(.secondary)
                    }

                    Stepper(
                        value: $project.traySettings.edgeMargin,
                        in: 5...25,
                        step: 1
                    ) {
                        Text("Adjust Margin")
                    }
                }

                Section("Details") {
                    HStack {
                        Text("Chamfer Size")
                        Spacer()
                        Text(String(format: "%.1f mm", project.traySettings.chamferSize))
                            .foregroundColor(.secondary)
                    }

                    Stepper(
                        value: $project.traySettings.chamferSize,
                        in: 0...3,
                        step: 0.25
                    ) {
                        Text("Adjust Chamfer")
                    }

                    Toggle("Add Drain Holes", isOn: $project.traySettings.addDrainHoles)

                    Toggle("Add Magnet Cavities", isOn: $project.traySettings.addMagnetCavities)

                    Toggle("Emboss Labels", isOn: $project.traySettings.embossLabels)
                }
            }
            .navigationTitle("Tray Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

// MARK: - Depth Legend
struct DepthLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach([(Color.blue, "Low"), (Color.cyan, ""), (Color.green, ""), (Color.yellow, ""), (Color.red, "High")], id: \.0) { item in
                if !item.1.isEmpty {
                    Text(item.1)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.0)
                    .frame(width: 12, height: 12)
            }
        }
    }
}
