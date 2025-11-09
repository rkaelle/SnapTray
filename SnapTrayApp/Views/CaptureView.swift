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
    @State private var showPlaneWarning = false
    @State private var capturePulse = false

    var body: some View {
        ZStack {
            // AR View
            ARCameraView(lidarManager: lidarManager)
                .edgesIgnoringSafeArea(.all)

            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.25)]), startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)

            if !lidarManager.isCapturing {
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                    Text("Initializing camera…")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
            }

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
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding([.top, .horizontal])

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
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding()
                }

                Spacer()

                // Status message
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding()

                // Capture button
                Button(action: {
                    guard !isProcessing else { return }
                    guard lidarManager.detectedPlane != nil else {
                        showPlaneWarning = true
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        statusMessage = "Need a flat surface — move to detect plane"
                        return
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.6)) { capturePulse.toggle() }
                    performCapture()
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 88, height: 88)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            )
                            .shadow(radius: 8)
                            .scaleEffect(capturePulse ? 1.05 : 1.0)

                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.4)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isProcessing)
                .padding(.bottom, 40)
                .alert("No plane detected", isPresented: $showPlaneWarning) {
                    Button("OK", role: .cancel) { showPlaneWarning = false }
                } message: {
                    Text("Point the camera at a flat, well-lit surface until the badge shows ‘Plane detected’.")
                }
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

    class Coordinator {
        let planeParentNode = SCNNode()
        let planeNode = SCNNode()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.automaticallyUpdatesLighting = true
        arView.session = lidarManager.arSession
        arView.backgroundColor = .black

        // Ensure a scene exists
        arView.scene = arView.scene ?? SCNScene()

        // Configure a child node that holds a rotated SCNPlane so its normal aligns with the plane normal
        let planeSize: CGFloat = 1.2 // meters, visual aid size
        let grid = SCNPlane(width: planeSize, height: planeSize)
        let material = SCNMaterial()
        material.diffuse.contents = makeGridImage(size: CGSize(width: 256, height: 256), gridSize: 16)
        material.isDoubleSided = true
        material.transparency = 0.6
        material.lightingModel = .physicallyBased
        grid.firstMaterial = material

        let coord = context.coordinator
        coord.planeNode.geometry = grid
        // Rotate plane so its normal (+z) becomes +y, matching our plane normal
        coord.planeNode.eulerAngles.x = -.pi / 2

        // Parent node will receive the world transform from detected plane
        coord.planeParentNode.isHidden = true
        coord.planeParentNode.addChildNode(coord.planeNode)

        arView.scene.rootNode.addChildNode(coord.planeParentNode)

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if uiView.session !== lidarManager.arSession {
            uiView.session = lidarManager.arSession
        }

        let coord = context.coordinator
        if let plane = lidarManager.detectedPlane {
            // Update transform for visual plane grid
            coord.planeParentNode.simdTransform = plane.transform
            if coord.planeParentNode.isHidden {
                coord.planeParentNode.isHidden = false
                // Simple fade-in for visual polish
                coord.planeParentNode.opacity = 0.0
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.25
                coord.planeParentNode.opacity = 1.0
                SCNTransaction.commit()
            }
        } else {
            // Hide when no plane
            coord.planeParentNode.isHidden = true
        }
    }

    private func makeGridImage(size: CGSize, gridSize: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            // Background slight tint
            context.setFillColor(UIColor(white: 1.0, alpha: 0.06).cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            // Grid lines
            context.setStrokeColor(UIColor(white: 1.0, alpha: 0.25).cgColor)
            context.setLineWidth(1)

            for x in stride(from: 0.0, through: size.width, by: gridSize) {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: gridSize) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.strokePath()

            // Crosshair at center
            context.setStrokeColor(UIColor(white: 1.0, alpha: 0.45).cgColor)
            context.setLineWidth(1.5)
            context.move(to: CGPoint(x: size.width/2, y: 0))
            context.addLine(to: CGPoint(x: size.width/2, y: size.height))
            context.move(to: CGPoint(x: 0, y: size.height/2))
            context.addLine(to: CGPoint(x: size.width, y: size.height/2))
            context.strokePath()
        }
    }
}
