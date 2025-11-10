import SwiftUI
import ARKit
import RealityKit

struct ManualCaptureView: View {
    let onCaptureDone: (Project) -> Void
    let onCancel: () -> Void

    @StateObject private var lidarManager = LiDARCaptureManager()
    @State private var captureMode: CaptureMode = .manual
    @State private var cornerPoints: [CGPoint] = []
    @State private var isProcessing = false
    @State private var statusMessage = "Position camera 60-100cm above tools"
    @State private var showGuide = true
    @State private var detectionStatus = DetectionStatus()
    @State private var reticlePosition: CGPoint = .zero
    @State private var screenSize: CGSize = .zero

    enum CaptureMode {
        case manual      // User taps to place corners
        case automatic   // ArUco marker detection
    }

    struct DetectionStatus {
        var planeDetected = false
        var arucoMarkersDetected = 0
        var planeQuality: String = "No plane"
        var lastUpdate = Date()
    }

    var body: some View {
        ZStack {
            // AR View
            ARCameraViewWithHitTest(
                lidarManager: lidarManager,
                onTap: handleTap,
                reticlePosition: $reticlePosition,
                screenSize: $screenSize
            )
            .edgesIgnoringSafeArea(.all)

            // Dark gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Corner markers overlay
            GeometryReader { geometry in
                ForEach(Array(cornerPoints.enumerated()), id: \.offset) { index, point in
                    CornerMarker(number: index + 1, isComplete: cornerPoints.count == 4)
                        .position(point)
                }

                // Draw lines between corners
                if cornerPoints.count >= 2 {
                    Path { path in
                        path.move(to: cornerPoints[0])
                        for i in 1..<cornerPoints.count {
                            path.addLine(to: cornerPoints[i])
                        }
                        if cornerPoints.count == 4 {
                            path.addLine(to: cornerPoints[0])
                        }
                    }
                    .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                }
            }
            .allowsHitTesting(false)

            // Reticle in center
            if captureMode == .manual && cornerPoints.count < 4 {
                Reticle()
                    .position(x: screenSize.width / 2, y: screenSize.height / 2)
            }

            // UI Overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: onCancel) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                    }

                    Spacer()

                    // Mode toggle
                    Button(action: toggleMode) {
                        HStack(spacing: 6) {
                            Image(systemName: captureMode == .manual ? "hand.tap.fill" : "viewfinder.circle.fill")
                            Text(captureMode == .manual ? "Manual" : "Auto")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()

                Spacer()

                // Detection status panel
                DetectionStatusPanel(status: detectionStatus, mode: captureMode)
                    .padding(.horizontal)

                Spacer()

                // Instructions
                if showGuide && captureMode == .manual {
                    ManualGuideView(cornerCount: cornerPoints.count, onDismiss: { showGuide = false })
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                }

                // Status message
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.thinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)

                // Action buttons
                HStack(spacing: 20) {
                    // Undo button (manual mode)
                    if captureMode == .manual && !cornerPoints.isEmpty {
                        Button(action: undoLastCorner) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 32))
                                Text("Undo")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.thinMaterial)
                            .cornerRadius(12)
                        }
                    }

                    // Main capture/place button
                    Button(action: handleMainAction) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 88, height: 88)
                                .overlay(
                                    Circle()
                                        .stroke(buttonColor, lineWidth: 4)
                                )
                                .shadow(radius: 8)

                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.4)
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: buttonIcon)
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(.white)
                                    if captureMode == .manual && cornerPoints.count < 4 {
                                        Text("\(cornerPoints.count)/4")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(isProcessing || !canCapture)

                    // Reset button (manual mode)
                    if captureMode == .manual && !cornerPoints.isEmpty {
                        Button(action: resetCorners) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 32))
                                Text("Reset")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.thinMaterial)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            lidarManager.startSession()
            startDetectionMonitoring()
        }
        .onDisappear {
            lidarManager.stopSession()
        }
    }

    private var buttonIcon: String {
        if captureMode == .manual {
            return cornerPoints.count < 4 ? "plus.circle.fill" : "camera.fill"
        } else {
            return "camera.fill"
        }
    }

    private var buttonColor: Color {
        if !canCapture { return .gray }
        if captureMode == .manual && cornerPoints.count == 4 { return .green }
        return .blue
    }

    private var canCapture: Bool {
        if captureMode == .manual {
            return cornerPoints.count == 4 && detectionStatus.planeDetected
        } else {
            return detectionStatus.planeDetected && detectionStatus.arucoMarkersDetected >= 4
        }
    }

    private func toggleMode() {
        captureMode = captureMode == .manual ? .automatic : .manual
        cornerPoints.removeAll()
        statusMessage = captureMode == .manual
            ? "Tap to place 4 corner points"
            : "Positioning camera to detect ArUco markers"
        showGuide = true
    }

    private func handleTap(at point: CGPoint) {
        guard captureMode == .manual && cornerPoints.count < 4 else { return }

        // Use center point as tap location (reticle position)
        let centerPoint = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        cornerPoints.append(centerPoint)

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Update status
        switch cornerPoints.count {
        case 1:
            statusMessage = "First corner placed. Tap to place second corner"
        case 2:
            statusMessage = "Second corner placed. Tap to place third corner"
        case 3:
            statusMessage = "Third corner placed. Tap to place fourth corner"
        case 4:
            statusMessage = "All corners placed! Tap capture to scan"
        default:
            break
        }
    }

    private func undoLastCorner() {
        guard !cornerPoints.isEmpty else { return }
        cornerPoints.removeLast()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        statusMessage = cornerPoints.isEmpty
            ? "Tap to place first corner"
            : "Tap to place corner \(cornerPoints.count + 1)"
    }

    private func resetCorners() {
        cornerPoints.removeAll()
        statusMessage = "Tap to place first corner"
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func handleMainAction() {
        if captureMode == .manual && cornerPoints.count < 4 {
            // Place corner at reticle position
            handleTap(at: CGPoint(x: screenSize.width / 2, y: screenSize.height / 2))
        } else {
            // Capture
            performCapture()
        }
    }

    private func startDetectionMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard !isProcessing else { return }

            // Update plane detection status
            detectionStatus.planeDetected = lidarManager.detectedPlane != nil
            detectionStatus.planeQuality = lidarManager.detectedPlane != nil ? "Good" : "No plane"

            // Check for ArUco markers if in automatic mode
            if captureMode == .automatic, let captured = lidarManager.capturedFrame {
                let detector = ArucoDetector()
                let detection = detector.detectMarkers(in: captured.image)
                detectionStatus.arucoMarkersDetected = detection.markers.count
            }

            detectionStatus.lastUpdate = Date()
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

        statusMessage = "Detecting workspace..."

        var workspaceBounds: CGRect
        var pixelToMMScale: Double = 1.0

        if captureMode == .manual && cornerPoints.count == 4 {
            // Use manual corners
            let minX = cornerPoints.map { $0.x }.min() ?? 0
            let maxX = cornerPoints.map { $0.x }.max() ?? captured.image.size.width
            let minY = cornerPoints.map { $0.y }.min() ?? 0
            let maxY = cornerPoints.map { $0.y }.max() ?? captured.image.size.height

            workspaceBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

            // Estimate scale based on assumed workspace size (e.g., 300mm width)
            let assumedWidthMM = 300.0
            pixelToMMScale = assumedWidthMM / Double(workspaceBounds.width)
        } else {
            // Use ArUco detection
            let arucoDetector = ArucoDetector()
            let detection = arucoDetector.detectMarkers(in: captured.image)
            workspaceBounds = detection.workspaceBounds ?? CGRect(x: 0, y: 0, width: captured.image.size.width, height: captured.image.size.height)
            pixelToMMScale = detection.pixelToMMScale ?? 1.0
        }

        // Segment tools
        statusMessage = "Detecting tools..."

        let segmenter = SegmentationProcessor()
        let segmentation = segmenter.segmentTools(
            image: captured.image,
            workspaceBounds: workspaceBounds
        )

        // Process geometry
        statusMessage = "Processing geometry..."

        let geometryProcessor = GeometryProcessor()
        var tools: [Tool] = []

        for contour in segmentation.contours {
            let simplified = geometryProcessor.simplifyContour(contour.points, tolerance: 2.0)

            let depths = lidarManager.getDepthAtContour(
                contour: simplified,
                plane: plane,
                allPoints: captured.depthData
            )

            let maxDepth = depths.isEmpty ? 10.0 : Double(depths.sorted().dropLast(Int(Double(depths.count) * 0.02)).last ?? 10.0)

            var tool = Tool(contour: simplified, maxDepth: maxDepth)

            let offset = -0.25
            tool.offsetContour = geometryProcessor.offsetContour(simplified, offset: offset)
            tool.offsetContour = geometryProcessor.applyFillets(tool.offsetContour, radius: 2.5)

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

        var project = Project(name: "Tray \(Date().formatted(date: .numeric, time: .omitted))")
        project.tools = tools
        project.workspaceBounds = workspaceBounds
        project.pixelToMMScale = pixelToMMScale

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

// MARK: - Reticle View
struct Reticle: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .opacity(pulse ? 0.0 : 1.0)

            // Inner ring
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 40, height: 40)

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)

            // Crosshair
            Path { path in
                path.move(to: CGPoint(x: -30, y: 0))
                path.addLine(to: CGPoint(x: -12, y: 0))
                path.move(to: CGPoint(x: 12, y: 0))
                path.addLine(to: CGPoint(x: 30, y: 0))
                path.move(to: CGPoint(x: 0, y: -30))
                path.addLine(to: CGPoint(x: 0, y: -12))
                path.move(to: CGPoint(x: 0, y: 12))
                path.addLine(to: CGPoint(x: 0, y: 30))
            }
            .stroke(Color.white, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 3)
        .onAppear {
            withAnimation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Corner Marker
struct CornerMarker: View {
    let number: Int
    let isComplete: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isComplete ? Color.green : Color.blue)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.5), radius: 5)

            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 50, height: 50)

            Text("\(number)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Detection Status Panel
struct DetectionStatusPanel: View {
    let status: ManualCaptureView.DetectionStatus
    let mode: ManualCaptureView.CaptureMode

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Plane detection
                StatusBadge(
                    icon: "cube.transparent",
                    label: "Plane",
                    value: status.planeQuality,
                    isGood: status.planeDetected
                )

                if mode == .automatic {
                    // ArUco markers
                    StatusBadge(
                        icon: "qrcode",
                        label: "Markers",
                        value: "\(status.arucoMarkersDetected)/4",
                        isGood: status.arucoMarkersDetected >= 4
                    )
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct StatusBadge: View {
    let icon: String
    let label: String
    let value: String
    let isGood: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isGood ? .green : .orange)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption.bold())
                    .foregroundColor(isGood ? .green : .orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Manual Guide
struct ManualGuideView: View {
    let cornerCount: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Manual Corner Selection")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                InstructionStep(
                    number: 1,
                    text: "Align reticle with workspace corner",
                    isActive: cornerCount == 0
                )
                InstructionStep(
                    number: 2,
                    text: "Tap to place corner marker",
                    isActive: cornerCount == 0
                )
                InstructionStep(
                    number: 3,
                    text: "Repeat for all 4 corners",
                    isActive: cornerCount > 0 && cornerCount < 4
                )
                InstructionStep(
                    number: 4,
                    text: "Tap capture when complete",
                    isActive: cornerCount == 4
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

private struct InstructionStep: View {
    let number: Int
    let text: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number).")
                .fontWeight(.bold)
                .foregroundColor(isActive ? .blue : .white.opacity(0.5))
                .frame(width: 20)

            Text(text)
                .foregroundColor(isActive ? .white : .white.opacity(0.7))
                .font(isActive ? .subheadline.bold() : .subheadline)
        }
    }
}

// MARK: - AR Camera View with Hit Testing
struct ARCameraViewWithHitTest: UIViewRepresentable {
    let lidarManager: LiDARCaptureManager
    let onTap: (CGPoint) -> Void
    @Binding var reticlePosition: CGPoint
    @Binding var screenSize: CGSize

    class Coordinator {
        let planeParentNode = SCNNode()
        let planeNode = SCNNode()
        var parent: ARCameraViewWithHitTest

        init(parent: ARCameraViewWithHitTest) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            parent.onTap(location)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.automaticallyUpdatesLighting = true
        arView.session = lidarManager.arSession
        arView.backgroundColor = .black
        arView.scene = SCNScene()

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        // Configure plane visualization (larger and more visible)
        let planeSize: CGFloat = 2.0  // Larger plane for better visibility
        let grid = SCNPlane(width: planeSize, height: planeSize)
        let material = SCNMaterial()
        material.diffuse.contents = makeGridImage(size: CGSize(width: 512, height: 512), gridSize: 32)
        material.isDoubleSided = true
        material.transparency = 0.75  // More visible
        material.lightingModel = .constant  // Always visible regardless of lighting
        grid.firstMaterial = material

        let coord = context.coordinator
        coord.planeNode.geometry = grid
        coord.planeNode.eulerAngles.x = -.pi / 2

        coord.planeParentNode.isHidden = true
        coord.planeParentNode.addChildNode(coord.planeNode)
        arView.scene.rootNode.addChildNode(coord.planeParentNode)

        // Update screen size
        DispatchQueue.main.async {
            screenSize = arView.bounds.size
            reticlePosition = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        }

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if uiView.session !== lidarManager.arSession {
            uiView.session = lidarManager.arSession
        }

        let coord = context.coordinator
        if let plane = lidarManager.detectedPlane {
            coord.planeParentNode.simdTransform = plane.transform
            if coord.planeParentNode.isHidden {
                coord.planeParentNode.isHidden = false
                coord.planeParentNode.opacity = 0.0
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.25
                coord.planeParentNode.opacity = 1.0
                SCNTransaction.commit()
            }
        } else {
            coord.planeParentNode.isHidden = true
        }

        // Update screen size
        DispatchQueue.main.async {
            screenSize = uiView.bounds.size
            reticlePosition = CGPoint(x: uiView.bounds.midX, y: uiView.bounds.midY)
        }
    }

    private func makeGridImage(size: CGSize, gridSize: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let context = ctx.cgContext

            // Semi-transparent blue background for better visibility
            context.setFillColor(UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.15).cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            // Grid lines - brighter and more visible
            context.setStrokeColor(UIColor(white: 1.0, alpha: 0.5).cgColor)
            context.setLineWidth(2)

            for x in stride(from: 0.0, through: size.width, by: gridSize) {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: gridSize) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.strokePath()

            // Center crosshair - more prominent
            context.setStrokeColor(UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.8).cgColor)
            context.setLineWidth(3)
            context.move(to: CGPoint(x: size.width/2, y: 0))
            context.addLine(to: CGPoint(x: size.width/2, y: size.height))
            context.move(to: CGPoint(x: 0, y: size.height/2))
            context.addLine(to: CGPoint(x: size.width, y: size.height/2))
            context.strokePath()
        }
    }
}
