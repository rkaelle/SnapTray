import SwiftUI
import ARKit

struct CaptureView: View {
    let onCaptureDone: (Project) -> Void
    let onCancel: () -> Void

    @StateObject private var lidarManager = LiDARCaptureManager()
    @State private var isProcessing = false
    @State private var capturedImage: UIImage?
    @State private var statusMessage = "Position camera 60-100cm above tools"
    @State private var showGuide = true

    var body: some View {
        ZStack {
            // AR View
            ARCameraView(lidarManager: lidarManager)
                .edgesIgnoringSafeArea(.all)

            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }

                    Spacer()

                    if lidarManager.detectedPlane != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Plane detected")
                                .foregroundColor(.white)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                }
                .padding()

                Spacer()

                // Guide overlay
                if showGuide {
                    VStack(spacing: 12) {
                        Text("Scan Guide")
                            .font(.headline)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 8) {
                            GuideStep(number: 1, text: "Place 4 markers at corners")
                            GuideStep(number: 2, text: "Arrange tools on dark background")
                            GuideStep(number: 3, text: "Hold phone ~60-100cm above")
                            GuideStep(number: 4, text: "Keep phone level")
                        }

                        Button(action: { showGuide = false }) {
                            Text("Got it")
                                .foregroundColor(.blue)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding()
                }

                Spacer()

                // Status message
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding()

                // Capture button
                Button(action: performCapture) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .frame(width: 80, height: 80)
                    } else {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                    }
                }
                .disabled(isProcessing || lidarManager.detectedPlane == nil)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            lidarManager.startSession()
        }
        .onDisappear {
            lidarManager.stopSession()
        }
    }

    private func performCapture() {
        isProcessing = true
        statusMessage = "Processing scan..."

        lidarManager.captureFrame()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processCapture()
        }
    }

    private func processCapture() {
        guard let captured = lidarManager.capturedFrame,
              let plane = lidarManager.detectedPlane else {
            statusMessage = "Failed to capture - please try again"
            isProcessing = false
            return
        }

        statusMessage = "Detecting fiducials..."

        // Detect ArUco markers
        let arucoDetector = ArucoDetector()
        let detection = arucoDetector.detectMarkers(in: captured.image)

        // Segment tools
        statusMessage = "Detecting tools..."

        let segmenter = SegmentationProcessor()
        let segmentation = segmenter.segmentTools(
            image: captured.image,
            workspaceBounds: detection.workspaceBounds
        )

        // Process geometry
        statusMessage = "Processing geometry..."

        let geometryProcessor = GeometryProcessor()
        var tools: [Tool] = []

        for contour in segmentation.contours {
            // Simplify contour
            let simplified = geometryProcessor.simplifyContour(contour.points, tolerance: 2.0)

            // Get depth for this contour
            let depths = lidarManager.getDepthAtContour(
                contour: simplified,
                plane: plane,
                allPoints: captured.depthData
            )

            let maxDepth = depths.isEmpty ? 10.0 : Double(depths.sorted().dropLast(Int(Double(depths.count) * 0.02)).last ?? 10.0)

            var tool = Tool(contour: simplified, maxDepth: maxDepth)

            // Apply offset based on default material
            let offset = -0.25  // PLA default
            tool.offsetContour = geometryProcessor.offsetContour(simplified, offset: offset)
            tool.offsetContour = geometryProcessor.applyFillets(tool.offsetContour, radius: 2.5)

            // Add finger notch
            let longestEdge = geometryProcessor.findLongestEdge(in: tool.offsetContour)
            let notchRadius = geometryProcessor.calculateNotchRadius(for: tool.boundingBox)

            let notch = FingerNotch(
                position: tool.offsetContour[longestEdge],
                radius: notchRadius,
                edgeIndex: longestEdge,
                normalizedPosition: 0.35
            )
            tool.fingerNotch = notch
            tool.offsetContour = geometryProcessor.addFingerNotch(to: tool.offsetContour, notch: notch)

            tools.append(tool)
        }

        // Create project
        var project = Project(name: "Tray \(Date().formatted(date: .numeric, time: .omitted))")
        project.tools = tools
        project.workspaceBounds = detection.workspaceBounds
        project.pixelToMMScale = detection.pixelToMMScale ?? 1.0

        // Save captured image
        if let imageData = captured.image.jpegData(compressionQuality: 0.8) {
            project.capturedImage = imageData
        }

        statusMessage = "Done!"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProcessing = false
            onCaptureDone(project)
        }
    }
}

struct GuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

struct ARCameraView: UIViewRepresentable {
    let lidarManager: LiDARCaptureManager

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.session = lidarManager.arSession ?? ARSession()
        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update if needed
    }
}
