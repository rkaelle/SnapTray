import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    let project: Project
    let onDone: () -> Void

    @State private var exportStatus: ExportStatus = .idle
    @State private var exportedFiles: [ExportedFile] = []
    @State private var showShareSheet = false
    @State private var showPrintSheet = false
    @State private var pdfData: Data?

    enum ExportStatus {
        case idle
        case exporting
        case completed
        case failed(String)
    }

    struct ExportedFile: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
        let type: FileType

        enum FileType {
            case dxf
            case stl
            case pdf

            var icon: String {
                switch self {
                case .dxf: return "doc.text.fill"
                case .stl: return "cube.fill"
                case .pdf: return "doc.fill"
                }
            }

            var color: Color {
                switch self {
                case .dxf: return .orange
                case .stl: return .blue
                case .pdf: return .red
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Files")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()
            }
            .padding()

            ScrollView {
                VStack(spacing: 20) {
                    // Export options
                    VStack(spacing: 15) {
                        ExportOptionCard(
                            title: "DXF for Foam/Laser",
                            subtitle: "2D cutting paths",
                            icon: "doc.text.fill",
                            color: .orange,
                            action: exportDXF
                        )

                        ExportOptionCard(
                            title: "STL for 3D Printing",
                            subtitle: "Ready for your Ender 3",
                            icon: "cube.fill",
                            color: .blue,
                            action: exportSTL
                        )

                        ExportOptionCard(
                            title: "PDF Report with Scale",
                            subtitle: "Print scan results and calibration",
                            icon: "doc.fill",
                            color: .red,
                            action: exportPDF
                        )

                        ExportOptionCard(
                            title: "Export All Formats",
                            subtitle: "DXF + STL + PDF",
                            icon: "square.stack.3d.up.fill",
                            color: .green,
                            action: exportAll
                        )
                    }
                    .padding(.horizontal)

                    // Export status
                    if case .exporting = exportStatus {
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)

                            Text("Generating files...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Exported files
                    if !exportedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exported Files")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(exportedFiles) { file in
                                FileCard(file: file, onShare: {
                                    shareFile(file.url)
                                })
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Success message
                    if case .completed = exportStatus {
                        VStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            Text("Files exported successfully!")
                                .font(.headline)

                            Text("Use the share buttons to save or send files")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Error message
                    if case .failed(let error) = exportStatus {
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)

                            Text("Export failed")
                                .font(.headline)

                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Steps")
                            .font(.headline)

                        InstructionStep(number: 1, text: "Export your desired file format(s)")
                        InstructionStep(number: 2, text: "For 3D printing: Send STL to your slicer (Cura, PrusaSlicer, etc.)")
                        InstructionStep(number: 3, text: "For foam/laser: Send DXF to your CNC or laser cutter")
                        InstructionStep(number: 4, text: "Print PDF for reference and scale verification")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }

            // Bottom button
            Button(action: onDone) {
                Text("Start New Scan")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }

    private func exportDXF() {
        exportStatus = .exporting

        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = DXFExporter()
            let scale = project.pixelToMMScale ?? 1.0
            let dxf = exporter.exportProject(project, scale: scale)

            let filename = "\(project.name.replacingOccurrences(of: " ", with: "_"))_pockets.dxf"

            if let url = exporter.saveToFile(dxf, filename: filename) {
                DispatchQueue.main.async {
                    exportedFiles.append(ExportedFile(name: filename, url: url, type: .dxf))
                    exportStatus = .completed
                }
            } else {
                DispatchQueue.main.async {
                    exportStatus = .failed("Failed to save DXF file")
                }
            }
        }
    }

    private func exportSTL() {
        exportStatus = .exporting

        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = STLExporter()
            let scale = project.pixelToMMScale ?? 1.0

            if let stlData = exporter.exportProject(project, scale: scale) {
                let filename = "\(project.name.replacingOccurrences(of: " ", with: "_"))_tray.stl"

                if let url = exporter.saveToFile(stlData, filename: filename) {
                    DispatchQueue.main.async {
                        exportedFiles.append(ExportedFile(name: filename, url: url, type: .stl))
                        exportStatus = .completed
                    }
                } else {
                    DispatchQueue.main.async {
                        exportStatus = .failed("Failed to save STL file")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    exportStatus = .failed("Failed to generate STL data")
                }
            }
        }
    }

    private func exportPDF() {
        exportStatus = .exporting

        DispatchQueue.global(qos: .userInitiated).async {
            let exporter = PDFExporter()

            let capturedImage = project.capturedImage.flatMap { UIImage(data: $0) }

            if let pdfData = exporter.generatePrintablePDF(project: project, capturedImage: capturedImage) {
                let filename = "\(project.name.replacingOccurrences(of: " ", with: "_"))_report.pdf"

                if let url = exporter.saveToFile(pdfData, filename: filename) {
                    DispatchQueue.main.async {
                        self.pdfData = pdfData
                        exportedFiles.append(ExportedFile(name: filename, url: url, type: .pdf))
                        exportStatus = .completed
                    }
                } else {
                    DispatchQueue.main.async {
                        exportStatus = .failed("Failed to save PDF file")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    exportStatus = .failed("Failed to generate PDF")
                }
            }
        }
    }

    private func exportAll() {
        exportStatus = .exporting
        exportedFiles.removeAll()

        DispatchQueue.global(qos: .userInitiated).async {
            // DXF
            let dxfExporter = DXFExporter()
            let scale = project.pixelToMMScale ?? 1.0
            let dxf = dxfExporter.exportProject(project, scale: scale)
            let dxfFilename = "\(project.name.replacingOccurrences(of: " ", with: "_"))_pockets.dxf"

            if let dxfUrl = dxfExporter.saveToFile(dxf, filename: dxfFilename) {
                DispatchQueue.main.async {
                    exportedFiles.append(ExportedFile(name: dxfFilename, url: dxfUrl, type: .dxf))
                }
            }

            // STL
            let stlExporter = STLExporter()
            if let stlData = stlExporter.exportProject(project, scale: scale) {
                let stlFilename = "\(project.name.replacingOccurrences(of: " ", with: "_"))_tray.stl"
                if let stlUrl = stlExporter.saveToFile(stlData, filename: stlFilename) {
                    DispatchQueue.main.async {
                        exportedFiles.append(ExportedFile(name: stlFilename, url: stlUrl, type: .stl))
                    }
                }
            }

            // PDF
            let pdfExporter = PDFExporter()
            let capturedImage = project.capturedImage.flatMap { UIImage(data: $0) }
            if let pdfData = pdfExporter.generatePrintablePDF(project: project, capturedImage: capturedImage) {
                let pdfFilename = "\(project.name.replacingOccurrences(of: " ", with: "_"))_report.pdf"
                if let pdfUrl = pdfExporter.saveToFile(pdfData, filename: pdfFilename) {
                    DispatchQueue.main.async {
                        self.pdfData = pdfData
                        exportedFiles.append(ExportedFile(name: pdfFilename, url: pdfUrl, type: .pdf))
                    }
                }
            }

            DispatchQueue.main.async {
                exportStatus = .completed
            }
        }
    }

    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct ExportOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(color)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

struct FileCard: View {
    let file: ExportView.ExportedFile
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: file.type.icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(file.type.color)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Ready to share")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}
