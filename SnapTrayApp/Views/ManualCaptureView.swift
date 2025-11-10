import SwiftUI
import ARKit
import RealityKit

struct ManualCaptureView: View {
    let onCaptureDone: (Project) -> Void
    let onCancel: () -> Void

    @StateObject private var lidarManager = LiDARCaptureManager()
    @State private var captureMode: CaptureMode = .manual
    @State private var cornerPoints: [CGPoint] = []  // 2D screen positions (for display)
    @State private var cornerWorldPositions: [simd_float3] = []  // 3D world positions (for accuracy)
    @State private var cornerScales: [CGFloat] = []  // Scale factors based on distance
    @State private var isProcessing = false
    @State private var statusMessage = "Position camera 60-100cm above tools"
    @State private var showGuide = true
    @State private var detectionStatus = DetectionStatus()
    @State private var reticlePosition: CGPoint = .zero
    @State private var screenSize: CGSize = .zero
    @State private var detectionTimer: Timer?
    @State private var detectedArucoMarkers: [DetectedArucoMarker] = []
    @State private var heatMapPoints: [CGPoint] = []  // Points above plane for heat map visualization
    @State private var showHeatMap = true  // Toggle heat map visibility

    enum CaptureMode {
        case manual      // User taps to place corners
        case automatic   // ArUco marker detection
    }

    struct DetectedArucoMarker: Identifiable {
        let id = UUID()
        let markerId: Int
        let corners: [CGPoint]
        let center: CGPoint
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
                    let scale = index < cornerScales.count ? cornerScales[index] : 1.0
                    CornerMarker(number: index + 1, isComplete: cornerPoints.count == 4, scale: scale)
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

                // ArUco markers overlay (in automatic mode)
                if captureMode == .automatic {
                    ForEach(detectedArucoMarkers) { marker in
                        // Calculate scale based on marker size (diagonal length)
                        let dx = marker.corners[2].x - marker.corners[0].x
                        let dy = marker.corners[2].y - marker.corners[0].y
                        let markerSize = sqrt(dx * dx + dy * dy)
                        let referenceSize: CGFloat = 200  // Reference marker size
                        let scale = markerSize / referenceSize
                        let clampedScale = min(max(scale, 0.5), 2.0)

                        // Draw marker outline
                        Path { path in
                            path.move(to: marker.corners[0])
                            for i in 1..<4 {
                                path.addLine(to: marker.corners[i])
                            }
                            path.closeSubpath()
                        }
                        .stroke(Color.green.opacity(0.8), lineWidth: 3 * clampedScale)

                        // Glow effect
                        Path { path in
                            path.move(to: marker.corners[0])
                            for i in 1..<4 {
                                path.addLine(to: marker.corners[i])
                            }
                            path.closeSubpath()
                        }
                        .stroke(Color.green.opacity(0.3), lineWidth: 8 * clampedScale)

                        // Marker ID label
                        Text("ID \(marker.markerId)")
                            .font(.system(size: 12 * clampedScale, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4 * clampedScale)
                            .background(Color.green)
                            .cornerRadius(4)
                            .position(marker.center)
                    }
                }

                // Heat map overlay - visualize points above plane
                if showHeatMap && !heatMapPoints.isEmpty {
                    ForEach(Array(heatMapPoints.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .position(point)
                    }
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

                    // Heat map toggle
                    Button(action: { showHeatMap.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: showHeatMap ? "circle.hexagongrid.fill" : "circle.hexagongrid")
                            Text("Heat")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(showHeatMap ? Color.orange : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

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
            detectionTimer?.invalidate()
            detectionTimer = nil
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
            // In manual mode:
            // - Always allow placing corners (< 4 corners)
            // - Only require plane detection when ready to capture (== 4 corners)
            return cornerPoints.count < 4 || detectionStatus.planeDetected
        } else {
            // In automatic mode, need both plane and markers
            return detectionStatus.planeDetected && detectionStatus.arucoMarkersDetected >= 4
        }
    }

    private func toggleMode() {
        captureMode = captureMode == .manual ? .automatic : .manual
        cornerPoints.removeAll()
        cornerWorldPositions.removeAll()
        cornerScales.removeAll()
        statusMessage = captureMode == .manual
            ? "Tap to place 4 corner points"
            : "Positioning camera to detect ArUco markers"
        showGuide = true

        // If switching to auto mode, check for markers once
        if captureMode == .automatic {
            checkForArucoMarkers()
        } else {
            // Reset marker count in manual mode
            detectionStatus.arucoMarkersDetected = 0
        }
    }

    private func handleTap(at point: CGPoint) {
        guard captureMode == .manual && cornerPoints.count < 4 else { return }
        guard let frame = lidarManager.arSession.currentFrame, let plane = lidarManager.detectedPlane else {
            statusMessage = "Waiting for plane detection..."
            return
        }

        // Use center point for hit testing (reticle position)
        let centerPoint = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)

        // Perform AR hit test at center of screen
        let normalizedPoint = CGPoint(
            x: centerPoint.x / screenSize.width,
            y: centerPoint.y / screenSize.height
        )

        // Raycast from camera through screen point to find intersection with plane
        if let worldPosition = hitTestPlane(normalizedPoint: normalizedPoint, plane: plane, frame: frame) {
            // Store 3D world position
            cornerWorldPositions.append(worldPosition)

            // Project to screen for display (will be updated each frame)
            if let screenPos = projectToScreen(worldPosition: worldPosition, frame: frame) {
                cornerPoints.append(screenPos)
            } else {
                // Fallback to center if projection fails
                cornerPoints.append(centerPoint)
            }

            // Calculate initial distance-based scale
            let cameraPosition = simd_float3(
                frame.camera.transform.columns.3.x,
                frame.camera.transform.columns.3.y,
                frame.camera.transform.columns.3.z
            )
            let distance = simd_distance(cameraPosition, worldPosition)
            let referenceDistance: Float = 0.8  // 80cm reference
            let scale = CGFloat(referenceDistance / distance)
            let clampedScale = min(max(scale, 0.5), 2.0)
            cornerScales.append(clampedScale)

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Update status
            switch cornerPoints.count {
            case 1:
                statusMessage = "First corner placed. Move to next corner"
            case 2:
                statusMessage = "Second corner placed. Move to next corner"
            case 3:
                statusMessage = "Third corner placed. Place final corner"
            case 4:
                statusMessage = "All corners placed! Tap capture to scan"
            default:
                break
            }
        } else {
            statusMessage = "Can't place point - no plane intersection"
        }
    }

    private func hitTestPlane(normalizedPoint: CGPoint, plane: LiDARCaptureManager.DetectedPlane, frame: ARFrame) -> simd_float3? {
        // Get camera position and create ray
        let cameraTransform = frame.camera.transform
        let cameraPosition = simd_float3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)

        // Convert normalized screen point to view direction
        let viewMatrix = frame.camera.viewMatrix(for: .portrait)
        let projectionMatrix = frame.camera.projectionMatrix(for: .portrait, viewportSize: screenSize, zNear: 0.001, zFar: 1000)

        // Convert from normalized screen space to NDC
        let ndcX = Float(normalizedPoint.x) * 2.0 - 1.0
        let ndcY = (1.0 - Float(normalizedPoint.y)) * 2.0 - 1.0

        // Unproject to get ray direction
        let invProjection = simd_inverse(projectionMatrix)
        let invView = simd_inverse(viewMatrix)

        let rayNDC = simd_float4(ndcX, ndcY, 1.0, 1.0)
        let rayEye = invProjection * rayNDC
        let rayEye4 = simd_float4(rayEye.x, rayEye.y, -1.0, 0.0)
        let rayWorld4 = invView * rayEye4
        let rayDirection = simd_normalize(simd_float3(rayWorld4.x, rayWorld4.y, rayWorld4.z))

        // Intersect ray with plane
        let planeNormal = plane.normal
        let planePoint = plane.center

        let denom = simd_dot(rayDirection, planeNormal)
        if abs(denom) > 0.0001 {
            let t = simd_dot(planePoint - cameraPosition, planeNormal) / denom
            if t > 0 {
                return cameraPosition + rayDirection * t
            }
        }

        return nil
    }

    private func projectToScreen(worldPosition: simd_float3, frame: ARFrame) -> CGPoint? {
        let viewMatrix = frame.camera.viewMatrix(for: .portrait)
        let projectionMatrix = frame.camera.projectionMatrix(for: .portrait, viewportSize: screenSize, zNear: 0.001, zFar: 1000)

        // Transform to clip space
        let worldPos4 = simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
        let viewPos = viewMatrix * worldPos4
        let clipPos = projectionMatrix * viewPos

        // Perspective divide
        if clipPos.w != 0 {
            let ndc = simd_float3(clipPos.x / clipPos.w, clipPos.y / clipPos.w, clipPos.z / clipPos.w)

            // Convert to screen coordinates
            let screenX = (ndc.x + 1.0) * 0.5 * Float(screenSize.width)
            let screenY = (1.0 - ndc.y) * 0.5 * Float(screenSize.height)

            return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
        }

        return nil
    }

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(Double(dx * dx + dy * dy))
    }

    private func downsampleImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxDim = max(size.width, size.height)

        // If already smaller, return original
        guard maxDim > maxDimension else { return image }

        let scale = maxDimension / maxDim
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized ?? image
    }

    private func undoLastCorner() {
        guard !cornerPoints.isEmpty else { return }
        cornerPoints.removeLast()
        cornerWorldPositions.removeLast()
        cornerScales.removeLast()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        statusMessage = cornerPoints.isEmpty
            ? "Tap to place first corner"
            : "Tap to place corner \(cornerPoints.count + 1)"
    }

    private func resetCorners() {
        cornerPoints.removeAll()
        cornerWorldPositions.removeAll()
        cornerScales.removeAll()
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
        // Invalidate any existing timer
        detectionTimer?.invalidate()

        // Create new timer and store it - runs frequently for smooth point tracking
        var lastMarkerCheck = Date()

        detectionTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [self] timer in
            guard !isProcessing else { return }

            // Get current AR frame - DO NOT STORE IT, just use it immediately
            if let frame = lidarManager.arSession.currentFrame {
                DispatchQueue.main.async {
                    // Update plane detection status
                    self.detectionStatus.planeDetected = self.lidarManager.detectedPlane != nil
                    self.detectionStatus.planeQuality = self.lidarManager.detectedPlane != nil ? "Good" : "No plane"
                    self.detectionStatus.lastUpdate = Date()

                    // Update corner point projections if we have placed points
                    if !self.cornerWorldPositions.isEmpty {
                        self.updateCornerProjections(frame: frame)
                    }

                    // Update heat map every frame if enabled
                    if self.showHeatMap {
                        self.updateHeatMap(frame: frame)
                    } else {
                        self.heatMapPoints.removeAll()
                    }

                    // Check for ArUco markers every 0.5 seconds in automatic mode
                    if self.captureMode == .automatic && Date().timeIntervalSince(lastMarkerCheck) > 0.5 {
                        lastMarkerCheck = Date()
                        self.checkForArucoMarkersLive()
                    }

                    // Frame is released here when it goes out of scope
                }
            }
        }
    }

    private func updateCornerProjections(frame: ARFrame) {
        // Re-project all 3D world positions to current screen coordinates
        var updatedPoints: [CGPoint] = []
        var updatedScales: [CGFloat] = []

        let cameraPosition = simd_float3(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )

        for worldPos in cornerWorldPositions {
            if let screenPos = projectToScreen(worldPosition: worldPos, frame: frame) {
                updatedPoints.append(screenPos)

                // Calculate distance-based scale
                let distance = simd_distance(cameraPosition, worldPos)
                let referenceDistance: Float = 0.8  // 80cm reference
                let scale = CGFloat(referenceDistance / distance)
                let clampedScale = min(max(scale, 0.5), 2.0)  // Clamp between 0.5x and 2.0x
                updatedScales.append(clampedScale)
            } else {
                // Keep old position if projection fails
                if updatedPoints.count < cornerPoints.count {
                    updatedPoints.append(cornerPoints[updatedPoints.count])
                    updatedScales.append(1.0)  // Default scale
                }
            }
        }

        // Update the display positions and scales
        if updatedPoints.count == cornerWorldPositions.count {
            cornerPoints = updatedPoints
            cornerScales = updatedScales
        }
    }

    private func updateHeatMap(frame: ARFrame) {
        guard let plane = lidarManager.detectedPlane,
              let sceneDepth = frame.sceneDepth else {
            heatMapPoints.removeAll()
            return
        }

        let depthMap = sceneDepth.depthMap
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let depthData = CVPixelBufferGetBaseAddress(depthMap) else {
            heatMapPoints.removeAll()
            return
        }

        let depthPointer = depthData.assumingMemoryBound(to: Float32.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        let floatsPerRow = rowBytes / MemoryLayout<Float32>.stride

        var points: [CGPoint] = []
        let heightThreshold: Float = 0.003  // 3mm above plane

        // Sample every 8th pixel for performance (still ~1000 points)
        let stepSize = 8

        for y in Swift.stride(from: 0, to: depthHeight, by: stepSize) {
            for x in Swift.stride(from: 0, to: depthWidth, by: stepSize) {
                let depth = depthPointer[y * floatsPerRow + x]
                guard depth > 0 && depth < 5.0 else { continue }

                // Convert depth pixel to 3D world position
                let normalizedX = Float(x) / Float(depthWidth - 1)
                let normalizedY = Float(y) / Float(depthHeight - 1)

                let viewportPoint = CGPoint(x: CGFloat(normalizedX), y: CGFloat(normalizedY))
                guard let ray = frame.camera.unprojectPoint(
                    viewportPoint,
                    ontoPlane: matrix_identity_float4x4,
                    orientation: .portrait,
                    viewportSize: CGSize(width: depthWidth, height: depthHeight)
                ) else {
                    continue
                }

                let worldPosition = ray * depth

                // Check if point is above plane
                let pointToPlane = worldPosition - plane.center
                let distance = simd_dot(pointToPlane, plane.normal)

                if distance > heightThreshold {
                    // Project 3D point to screen
                    if let screenPos = projectToScreen(worldPosition: worldPosition, frame: frame) {
                        points.append(screenPos)
                    }
                }
            }
        }

        // Limit to reasonable number of points for performance
        if points.count > 2000 {
            points = Array(points.prefix(2000))
        }

        heatMapPoints = points
    }

    private func checkForArucoMarkersLive() {
        // Get current frame for detection
        guard let currentFrame = lidarManager.arSession.currentFrame else { return }

        let pixelBuffer = currentFrame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        // Run marker detection in background to avoid UI lag
        DispatchQueue.global(qos: .userInitiated).async {
            let detector = ArucoDetector()
            let detection = detector.detectMarkers(in: image)

            // Update UI on main thread
            DispatchQueue.main.async {
                self.detectionStatus.arucoMarkersDetected = detection.markers.count

                // Update visual markers overlay
                self.detectedArucoMarkers = detection.markers.map { marker in
                    DetectedArucoMarker(
                        markerId: marker.id,
                        corners: marker.corners,
                        center: marker.center
                    )
                }
            }
        }
    }

    private func checkForArucoMarkers() {
        // Only check in auto mode
        guard captureMode == .automatic else { return }

        // Capture a frame to check for markers
        lidarManager.captureFrame()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let captured = self.lidarManager.capturedFrame else { return }

            // Run marker detection in background to avoid UI lag
            DispatchQueue.global(qos: .userInitiated).async {
                let detector = ArucoDetector()
                let detection = detector.detectMarkers(in: captured.image)

                // Update UI on main thread
                DispatchQueue.main.async {
                    self.detectionStatus.arucoMarkersDetected = detection.markers.count
                }
            }
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

        // Move heavy processing to background thread to prevent memory spikes
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                self.performProcessing(captured: captured, plane: plane)
            }
        }
    }

    private func performProcessing(captured: LiDARCaptureManager.CapturedFrame, plane: LiDARCaptureManager.DetectedPlane) {
        DispatchQueue.main.async {
            self.statusMessage = "Detecting workspace..."
        }

        var workspaceBounds: CGRect
        var pixelToMMScale: Double = 1.0

        if captureMode == .manual && cornerPoints.count == 4 && cornerWorldPositions.count == 4 {
            // Use manual corners - project world positions to final image
            guard let finalFrame = lidarManager.arSession.currentFrame else {
                DispatchQueue.main.async {
                    self.statusMessage = "No frame available"
                    self.isProcessing = false
                }
                return
            }

            // Project all 4 world positions to screen coordinates on the captured image
            var projectedCorners: [CGPoint] = []
            for worldPos in cornerWorldPositions {
                if let screenPos = projectToScreen(worldPosition: worldPos, frame: finalFrame) {
                    projectedCorners.append(screenPos)
                }
            }

            // Ensure we got all 4 corners projected
            guard projectedCorners.count == 4 else {
                DispatchQueue.main.async {
                    self.statusMessage = "Failed to project corners - please try again"
                    self.isProcessing = false
                }
                return
            }

            // Use projected corners for bounds
            let minX = projectedCorners.map { $0.x }.min() ?? 0
            let maxX = projectedCorners.map { $0.x }.max() ?? captured.image.size.width
            let minY = projectedCorners.map { $0.y }.min() ?? 0
            let maxY = projectedCorners.map { $0.y }.max() ?? captured.image.size.height

            // Add padding to workspace bounds to be more forgiving (10% on each side)
            let boundsWidth = maxX - minX
            let boundsHeight = maxY - minY
            let paddingX = boundsWidth * 0.1
            let paddingY = boundsHeight * 0.1

            workspaceBounds = CGRect(
                x: max(0, minX - paddingX),
                y: max(0, minY - paddingY),
                width: min(captured.image.size.width - max(0, minX - paddingX), boundsWidth + 2 * paddingX),
                height: min(captured.image.size.height - max(0, minY - paddingY), boundsHeight + 2 * paddingY)
            )

            print("📦 Workspace bounds (with padding): \(workspaceBounds)")
            print("   Corners projected: \(projectedCorners)")
            print("   Image size: \(captured.image.size)")

            // Calculate real-world scale from 3D distances
            // Use the distance between first two corners as reference
            let worldDist1 = simd_distance(cornerWorldPositions[0], cornerWorldPositions[1])
            let worldDist2 = simd_distance(cornerWorldPositions[1], cornerWorldPositions[2])
            let avgWorldWidth = Double(worldDist1 + worldDist2) / 2.0  // meters, converted to Double

            let pixelDist1 = distance(projectedCorners[0], projectedCorners[1])
            let pixelDist2 = distance(projectedCorners[1], projectedCorners[2])
            let avgPixelWidth = (pixelDist1 + pixelDist2) / 2.0  // pixels

            // Convert meters to mm and calculate scale
            let worldWidthMM = avgWorldWidth * 1000.0  // Convert to mm
            pixelToMMScale = worldWidthMM / avgPixelWidth
        } else {
            // Use ArUco detection
            let arucoDetector = ArucoDetector()
            let detection = arucoDetector.detectMarkers(in: captured.image)
            workspaceBounds = detection.workspaceBounds ?? CGRect(x: 0, y: 0, width: captured.image.size.width, height: captured.image.size.height)
            pixelToMMScale = detection.pixelToMMScale ?? 1.0
        }

        // Validate phone angle (should be parallel to plane)
        let cameraTransform = captured.cameraTransform
        let cameraForward = simd_float3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        let angleToPlane = acos(abs(simd_dot(cameraForward, plane.normal)))
        let angleDegrees = angleToPlane * 180.0 / .pi

        print("📐 Camera angle to plane: \(angleDegrees)°")

        if angleDegrees > 30 {
            DispatchQueue.main.async {
                self.statusMessage = "⚠️ Hold phone more parallel to surface"
                self.isProcessing = false
            }
            return
        }

        // Segment tools using DEPTH DATA (not image processing!)
        DispatchQueue.main.async {
            self.statusMessage = "Detecting tools from depth..."
        }

        print("🔍 Starting tool detection...")
        print("   Depth points: \(captured.depthData.count)")
        print("   Depth map size: \(captured.depthMapSize)")
        print("   Image size: \(captured.image.size)")

        let segmenter = SegmentationProcessor()

        // Use depth-based segmentation - finds objects above the plane
        let segmentation = segmenter.segmentToolsFromDepth(
            depthPoints: captured.depthData,
            plane: plane,
            cameraTransform: captured.cameraTransform,
            cameraIntrinsics: captured.cameraIntrinsics,
            imageSize: captured.image.size,
            depthMapSize: captured.depthMapSize,  // Use actual depth map size
            workspaceBounds: workspaceBounds,
            heightThreshold: 0.003  // 3mm above plane (lowered for better detection)
        )

        print("✅ Found \(segmentation.contours.count) contours")

        let scaledContours = segmentation.contours

        // Process geometry
        DispatchQueue.main.async {
            self.statusMessage = "Processing geometry..."
        }

        let geometryProcessor = GeometryProcessor()
        var tools: [Tool] = []

        for contour in scaledContours {
            autoreleasepool {
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
        }

        // Use filename-safe date format (no slashes)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        var project = Project(name: "Tray \(dateString)")
        project.tools = tools
        project.workspaceBounds = workspaceBounds
        project.pixelToMMScale = pixelToMMScale

        if let imageData = captured.image.jpegData(compressionQuality: 0.8) {
            project.capturedImage = imageData
        }

        DispatchQueue.main.async {
            self.statusMessage = "Done!"
        }

        // Clear captured frame to free memory
        DispatchQueue.main.async {
            self.lidarManager.capturedFrame = nil
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessing = false
            self.onCaptureDone(project)
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
    let scale: CGFloat  // Distance-based scale factor

    var body: some View {
        let size = 50 * scale
        let strokeWidth = 3 * scale
        let fontSize = 20 * scale

        ZStack {
            Circle()
                .fill(isComplete ? Color.green : Color.blue)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.5), radius: 5 * scale)

            Circle()
                .stroke(Color.white, lineWidth: strokeWidth)
                .frame(width: size, height: size)

            Text("\(number)")
                .font(.system(size: fontSize, weight: .bold))
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
