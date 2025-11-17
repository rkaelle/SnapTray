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
    @State private var processingProgress: Double = 0.0
    @State private var processingStatus: String = ""
    @State private var navigateToProcessing = false  // Navigation trigger for processing page
    @State private var completedProject: Project?  // Store completed project for handoff
    @State private var statusMessage = "Position camera 60-100cm above tools"
    @State private var showGuide = true
    @State private var detectionStatus = DetectionStatus()
    @State private var reticlePosition: CGPoint = .zero
    @State private var screenSize: CGSize = .zero
    @State private var detectionTimer: Timer?
    @State private var detectedArucoMarkers: [DetectedArucoMarker] = []
    @State private var heatMapPoints: [CGPoint] = []  // Points above plane for heat map visualization
    // Heat map removed - was not working properly

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
        var distanceToPlane: Float = 0  // Distance from camera to plane in cm
        var angleToPlane: Float = 0  // Angle in degrees
        var pointsAbovePlane: Int = 0  // Number of depth points above plane
    }

    var body: some View {
        ZStack {
            // Main capture interface
            mainCaptureView

            // Full screen processing overlay when processing
            if navigateToProcessing {
                ProcessingPageView(
                    statusMessage: $processingStatus,
                    progress: $processingProgress,
                    onComplete: {
                        // When processing completes, call the done handler
                        navigateToProcessing = false
                        if let project = completedProject {
                            onCaptureDone(project)
                        }
                    }
                )
                .transition(AnyTransition.opacity)
                .zIndex(100)
            }
        }
    }

    private var mainCaptureView: some View {
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

                // Heat map removed - was not working properly and cluttered the view
            }
            .allowsHitTesting(false)

            // Reticle in center
            if captureMode == .manual && cornerPoints.count < 4 {
                Reticle()
                    .position(x: screenSize.width / 2, y: screenSize.height / 2)
            }

            // UI Overlay - Minimal HUD design
            VStack {
                // Top HUD bar with enhanced glassmorphism
                VStack(spacing: 12) {
                    HStack {
                        Button(action: onCancel) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("Cancel")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Spacer()

                        // Mode toggle with gradient
                        Button(action: toggleMode) {
                            HStack(spacing: 6) {
                                Image(systemName: captureMode == .manual ? "hand.tap.fill" : "viewfinder.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(captureMode == .manual ? "Manual" : "Auto")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: Color.blue.opacity(0.4), radius: 8, y: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    // Compact Detection status panel
                    CompactDetectionStatusPanel(status: detectionStatus, mode: captureMode)

                    // Compact instructions - only show when manual mode and placing corners
                    if showGuide && captureMode == .manual && cornerPoints.count < 4 {
                        CompactGuideView(cornerCount: cornerPoints.count, onDismiss: { showGuide = false })
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding()

                Spacer()  // This pushes everything to top and bottom, keeping center clear

                // Status message at bottom with minimal design
                Text(statusMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal)

                // Action buttons with enhanced styling
                HStack(spacing: 20) {
                    // Undo button (manual mode)
                    if captureMode == .manual && !cornerPoints.isEmpty {
                        Button(action: undoLastCorner) {
                            VStack(spacing: 6) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.system(size: 36))
                                Text("Undo")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(18)
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    // Main capture/place button with enhanced glassmorphism
                    Button(action: handleMainAction) {
                        ZStack {
                            // Outer glow ring
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [buttonColor.opacity(0.3), buttonColor.opacity(0)],
                                        center: .center,
                                        startRadius: 44,
                                        endRadius: 60
                                    )
                                )
                                .frame(width: 120, height: 120)

                            // Main button background
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 88, height: 88)
                                .background(
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [buttonColor.opacity(0.2), buttonColor.opacity(0.05)],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 44
                                            )
                                        )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [buttonColor, buttonColor.opacity(0.6)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 4
                                        )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        .padding(2)
                                )
                                .shadow(color: buttonColor.opacity(0.4), radius: 15, y: 8)
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.4)
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: buttonIcon)
                                        .font(.system(size: 30, weight: .semibold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.white, .white.opacity(0.9)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    if captureMode == .manual && cornerPoints.count < 4 {
                                        Text("\(cornerPoints.count)/4")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                        }
                    }
                    .disabled(isProcessing || !canCapture)
                    .buttonStyle(ScaleButtonStyle())
                    .scaleEffect(isProcessing ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isProcessing)

                    // Reset button (manual mode)
                    if captureMode == .manual && !cornerPoints.isEmpty {
                        Button(action: resetCorners) {
                            VStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 36))
                                Text("Reset")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(18)
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
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

        // Create new timer and store it - runs at 10Hz (100ms) for better performance
        var lastMarkerCheck = Date()
        var lastPointsUpdate = Date()

        detectionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] timer in
            guard !isProcessing else { return }

            // Get current AR frame - DO NOT STORE IT, just use it immediately
            if let frame = lidarManager.arSession.currentFrame {
                DispatchQueue.main.async {
                    // Update plane detection status
                    self.detectionStatus.planeDetected = self.lidarManager.detectedPlane != nil
                    self.detectionStatus.planeQuality = self.lidarManager.detectedPlane != nil ? "Good" : "No plane"
                    self.detectionStatus.lastUpdate = Date()

                    // Calculate live stats if plane detected
                    if let plane = self.lidarManager.detectedPlane {
                        let cameraPos = simd_float3(
                            frame.camera.transform.columns.3.x,
                            frame.camera.transform.columns.3.y,
                            frame.camera.transform.columns.3.z
                        )

                        // Distance from camera to plane
                        let distanceMeters = simd_distance(cameraPos, plane.center)
                        self.detectionStatus.distanceToPlane = distanceMeters * 100 // Convert to cm

                        // Angle between camera forward and plane normal
                        let cameraForward = simd_float3(
                            frame.camera.transform.columns.2.x,
                            frame.camera.transform.columns.2.y,
                            frame.camera.transform.columns.2.z
                        )
                        let angleRad = acos(abs(simd_dot(cameraForward, plane.normal)))
                        self.detectionStatus.angleToPlane = angleRad * 180.0 / .pi

                        // Count points above plane (only update occasionally to save performance)
                        if Date().timeIntervalSince(lastPointsUpdate) > 0.3 {
                            lastPointsUpdate = Date()
                            if let sceneDepth = frame.sceneDepth {
                                self.detectionStatus.pointsAbovePlane = self.countPointsAbovePlane(
                                    frame: frame,
                                    plane: plane,
                                    sceneDepth: sceneDepth
                                )
                            }
                        }
                    }

                    // Update corner point projections if we have placed points
                    if !self.cornerWorldPositions.isEmpty {
                        self.updateCornerProjections(frame: frame)
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

    private func countPointsAbovePlane(frame: ARFrame, plane: LiDARCaptureManager.DetectedPlane, sceneDepth: ARDepthData) -> Int {
        let depthMap = sceneDepth.depthMap
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let depthData = CVPixelBufferGetBaseAddress(depthMap) else {
            return 0
        }

        let depthPointer = depthData.assumingMemoryBound(to: Float32.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        let floatsPerRow = rowBytes / MemoryLayout<Float32>.stride

        var count = 0
        let heightThreshold: Float = 0.001  // 1mm

        // Sample every 8th pixel for speed
        for y in Swift.stride(from: 0, to: depthHeight, by: 8) {
            for x in Swift.stride(from: 0, to: depthWidth, by: 8) {
                let depth = depthPointer[y * floatsPerRow + x]
                guard depth > 0 && depth < 5.0 else { continue }

                let normalizedX = Float(x) / Float(depthWidth - 1)
                let normalizedY = Float(y) / Float(depthHeight - 1)
                let viewportPoint = CGPoint(x: CGFloat(normalizedX), y: CGFloat(normalizedY))

                guard let ray = frame.camera.unprojectPoint(
                    viewportPoint,
                    ontoPlane: matrix_identity_float4x4,
                    orientation: .portrait,
                    viewportSize: CGSize(width: depthWidth, height: depthHeight)
                ) else { continue }

                let worldPosition = ray * depth
                let pointToPlane = worldPosition - plane.center
                let distanceAbovePlane = simd_dot(pointToPlane, plane.normal)

                if distanceAbovePlane > heightThreshold {
                    count += 1
                }
            }
        }

        return count
    }

    // Heat map function removed - feature was not working properly

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
        statusMessage = "Preparing scan..."

        // Navigate to processing page
        navigateToProcessing = true

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
            self.processingStatus = "Setting up workspace..."
            self.processingProgress = 0.05
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

            DispatchQueue.main.async {
                self.processingStatus = "Projecting workspace corners..."
                self.processingProgress = 0.1
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
            DispatchQueue.main.async {
                self.processingStatus = "Detecting ArUco markers..."
                self.processingProgress = 0.1
            }

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

        // SENSOR FUSION: Blend RGB camera with LiDAR depth for enhanced accuracy
        DispatchQueue.main.async {
            self.processingStatus = "Initializing sensor fusion..."
            self.processingProgress = 0.15
        }

        print("🔍 Starting sensor fusion...")
        print("   Depth points: \(captured.depthData.count)")
        print("   Depth map size: \(captured.depthMapSize)")
        print("   Image size: \(captured.image.size)")

        // Use SensorFusionProcessor to enhance depth with RGB edges
        let fusionProcessor = SensorFusionProcessor()
        let fusedResult = fusionProcessor.fuseRGBWithDepth(
            rgbImage: captured.image,
            depthPoints: captured.depthData,
            depthMapSize: captured.depthMapSize,
            imageSize: captured.image.size,
            minDepthChange: 0.005  // 5mm sensitivity for edge detection
        )

        DispatchQueue.main.async {
            self.processingStatus = "Sensor fusion complete - using enhanced depth..."
            self.processingProgress = 0.20
        }

        // Use enhanced depth points if available, otherwise fall back to raw LiDAR
        let depthPointsToUse: [LiDARCaptureManager.DepthPoint]
        if let fusedData = fusedResult {
            print("   ✅ Sensor fusion successful - using \(fusedData.depthPoints.count) enhanced points")
            depthPointsToUse = fusionProcessor.convertToStandardDepthPoints(fusedData.depthPoints)
        } else {
            print("   ⚠️ Sensor fusion failed - using raw LiDAR depth")
            depthPointsToUse = captured.depthData
        }

        // Segment tools using enhanced depth data
        DispatchQueue.main.async {
            self.processingStatus = "Detecting tool outlines..."
            self.processingProgress = 0.25
        }

        print("🔍 Starting tool detection with \(depthPointsToUse.count) depth points...")

        let segmenter = SegmentationProcessor()

        // Use depth-based segmentation with detailed progress callbacks
        var lastProgress: Double = 0.25
        let segmentation = segmenter.segmentToolsFromDepth(
            depthPoints: depthPointsToUse,
            plane: plane,
            cameraTransform: captured.cameraTransform,
            cameraIntrinsics: captured.cameraIntrinsics,
            imageSize: captured.image.size,
            depthMapSize: captured.depthMapSize,
            workspaceBounds: workspaceBounds,
            heightThreshold: 0.001,  // 1mm sensitivity for depth detection
            progressCallback: { status in
                DispatchQueue.main.async {
                    self.processingStatus = status
                    // Gradually increment progress from 0.25 to 0.50
                    lastProgress = min(0.50, lastProgress + 0.02)
                    self.processingProgress = lastProgress
                }
            }
        )

        print("✅ Found \(segmentation.contours.count) contours")

        DispatchQueue.main.async {
            self.processingStatus = "Found \(segmentation.contours.count) tools - processing shapes..."
            self.processingProgress = 0.5
        }

        let scaledContours = segmentation.contours

        // Process geometry with progress updates
        let geometryProcessor = GeometryProcessor()
        var tools: [Tool] = []

        for (index, contour) in scaledContours.enumerated() {
            autoreleasepool {
                // Update progress smoothly for each tool (0.50 -> 0.75)
                let toolProgress = 0.50 + (0.25 * Double(index) / Double(max(scaledContours.count, 1)))
                DispatchQueue.main.async {
                    self.processingStatus = "Refining tool \(index + 1) of \(scaledContours.count)..."
                    self.processingProgress = toolProgress
                }

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

        DispatchQueue.main.async {
            self.processingStatus = "Saving project data..."
            self.processingProgress = 0.75
        }

        // Use filename-safe date format (no slashes)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        var project = Project(name: "Tray \(dateString)")
        project.tools = tools
        project.workspaceBounds = workspaceBounds
        project.pixelToMMScale = pixelToMMScale

        // Crop captured image to workspace bounds for cleaner output
        let croppedImage = cropImageToWorkspace(captured.image, workspaceBounds: workspaceBounds)
        if let imageData = croppedImage.jpegData(compressionQuality: 0.8) {
            project.capturedImage = imageData
        }

        // OPTIMIZED: Generate depth map with faster single-pass algorithm
        DispatchQueue.main.async {
            self.processingStatus = "Creating depth visualization..."
            self.processingProgress = 0.80
        }

        if let depthMapImage = self.generateOptimizedDepthMapVisualization(
            depthPoints: captured.depthData,
            plane: plane,
            imageSize: captured.image.size,
            depthMapSize: captured.depthMapSize,
            workspaceBounds: workspaceBounds
        ) {
            if let depthMapData = depthMapImage.jpegData(compressionQuality: 0.85) {
                project.depthMap = depthMapData
            }
        }

        DispatchQueue.main.async {
            self.processingStatus = "Finalizing..."
            self.processingProgress = 0.90
        }

        // Smooth progress to 100%
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.processingStatus = "Complete!"
            self.processingProgress = 1.0

            // Store completed project
            self.completedProject = project

            // Clear captured frame to free memory
            self.lidarManager.capturedFrame = nil
            self.isProcessing = false
        }
    }

    private func generateDepthMapVisualization(
        depthPoints: [LiDARCaptureManager.DepthPoint],
        plane: LiDARCaptureManager.DetectedPlane,
        imageSize: CGSize,
        depthMapSize: CGSize
    ) -> UIImage? {
        // Use reasonable output resolution (4x upsampling from LiDAR)
        let targetWidth = 1024
        let targetHeight = Int(CGFloat(targetWidth) * imageSize.height / imageSize.width)
        let width = targetWidth
        let height = targetHeight

        // Find min/max heights above plane for color mapping
        var minHeight: Float = Float.infinity
        var maxHeight: Float = -Float.infinity

        for point in depthPoints {
            let pointToPlane = point.position - plane.center
            let distance = simd_dot(pointToPlane, plane.normal)
            if distance > 0 {
                minHeight = min(minHeight, distance)
                maxHeight = max(maxHeight, distance)
            }
        }

        // If no points above plane, return nil
        guard minHeight != Float.infinity else { return nil }

        let heightRange = max(maxHeight - minHeight, 0.001)

        // Create sparse depth map at original resolution
        let sparseWidth = Int(depthMapSize.width)
        let sparseHeight = Int(depthMapSize.height)
        var sparseDepth = [Float](repeating: -1, count: sparseWidth * sparseHeight)

        // Fill sparse depth map
        for point in depthPoints {
            let pointToPlane = point.position - plane.center
            let distance = simd_dot(pointToPlane, plane.normal)

            if distance > 0 {
                let x = point.pixelX
                let y = point.pixelY
                if x >= 0 && x < sparseWidth && y >= 0 && y < sparseHeight {
                    sparseDepth[y * sparseWidth + x] = distance
                }
            }
        }

        // Upsample to full resolution with bilateral filtering
        let scaleX = Float(width) / Float(sparseWidth)
        let scaleY = Float(height) / Float(sparseHeight)

        var denseDepth = [Float](repeating: -1, count: width * height)

        // Multi-pass interpolation for smoother results
        for pass in 0..<2 {
            let radius = pass == 0 ? 8 : 4

            for y in 0..<height {
                for x in 0..<width {
                    // Map to sparse coordinates
                    let sx = Float(x) / scaleX
                    let sy = Float(y) / scaleY

                    // Weighted average of nearby sparse points
                    var sumWeight: Float = 0
                    var sumDepth: Float = 0

                    let searchRadius = radius
                    let minSX = max(0, Int(sx) - searchRadius)
                    let maxSX = min(sparseWidth - 1, Int(sx) + searchRadius)
                    let minSY = max(0, Int(sy) - searchRadius)
                    let maxSY = min(sparseHeight - 1, Int(sy) + searchRadius)

                    for ssy in minSY...maxSY {
                        for ssx in minSX...maxSX {
                            let idx = ssy * sparseWidth + ssx
                            if sparseDepth[idx] > 0 {
                                // Distance-based weight
                                let dx = Float(ssx) - sx
                                let dy = Float(ssy) - sy
                                let dist = sqrt(dx * dx + dy * dy)
                                let weight = exp(-dist * dist / Float(searchRadius * searchRadius))

                                sumWeight += weight
                                sumDepth += sparseDepth[idx] * weight
                            }
                        }
                    }

                    if sumWeight > 0.001 {
                        denseDepth[y * width + x] = sumDepth / sumWeight
                    }
                }
            }
        }

        // Create color visualization
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let depth = denseDepth[y * width + x]

                if depth > 0 {
                    // Normalize height to 0-1 range
                    let normalizedHeight = (depth - minHeight) / heightRange

                    // Convert to heat map color
                    let (r, g, b) = heightToColor(normalizedHeight: CGFloat(normalizedHeight))

                    let pixelIndex = (y * width + x) * 4
                    pixels[pixelIndex] = UInt8(r * 255)
                    pixels[pixelIndex + 1] = UInt8(g * 255)
                    pixels[pixelIndex + 2] = UInt8(b * 255)
                    pixels[pixelIndex + 3] = 255
                }
            }
        }

        // Create CGImage from pixel data
        guard let providerRef = CGDataProvider(data: Data(pixels) as CFData) else { return nil }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    // OPTIMIZED: Single-pass depth map generation with faster nearest neighbor interpolation
    private func generateOptimizedDepthMapVisualization(
        depthPoints: [LiDARCaptureManager.DepthPoint],
        plane: LiDARCaptureManager.DetectedPlane,
        imageSize: CGSize,
        depthMapSize: CGSize,
        workspaceBounds: CGRect? = nil
    ) -> UIImage? {
        // Use more reasonable resolution for faster processing
        let targetWidth = 800  // Reduced from 1024 for speed
        let targetHeight = Int(CGFloat(targetWidth) * imageSize.height / imageSize.width)
        let width = targetWidth
        let height = targetHeight

        // Find min/max heights above plane for color mapping
        var minHeight: Float = Float.infinity
        var maxHeight: Float = -Float.infinity

        for point in depthPoints {
            let pointToPlane = point.position - plane.center
            let distance = simd_dot(pointToPlane, plane.normal)
            if distance > 0 {
                minHeight = min(minHeight, distance)
                maxHeight = max(maxHeight, distance)
            }
        }

        // If no points above plane, return nil
        guard minHeight != Float.infinity else { return nil }

        let heightRange = max(maxHeight - minHeight, 0.001)

        // Create sparse depth map at original resolution
        let sparseWidth = Int(depthMapSize.width)
        let sparseHeight = Int(depthMapSize.height)
        var sparseDepth = [Float](repeating: -1, count: sparseWidth * sparseHeight)

        // Scale workspace bounds to depth map size for filtering
        let scaledWorkspaceBounds: CGRect?
        if let bounds = workspaceBounds {
            let scaleX = depthMapSize.width / imageSize.width
            let scaleY = depthMapSize.height / imageSize.height
            scaledWorkspaceBounds = CGRect(
                x: bounds.origin.x * scaleX,
                y: bounds.origin.y * scaleY,
                width: bounds.width * scaleX,
                height: bounds.height * scaleY
            )
        } else {
            scaledWorkspaceBounds = nil
        }

        // Fill sparse depth map - only within workspace bounds
        for point in depthPoints {
            let pointToPlane = point.position - plane.center
            let distance = simd_dot(pointToPlane, plane.normal)

            if distance > 0 {
                let x = point.pixelX
                let y = point.pixelY

                // Filter by workspace bounds if provided
                if let bounds = scaledWorkspaceBounds {
                    let pointInBounds = CGPoint(x: CGFloat(x), y: CGFloat(y))
                    guard bounds.contains(pointInBounds) else {
                        continue
                    }
                }

                if x >= 0 && x < sparseWidth && y >= 0 && y < sparseHeight {
                    sparseDepth[y * sparseWidth + x] = distance
                }
            }
        }

        // Single-pass nearest neighbor upsampling (much faster!)
        let scaleX = Float(width) / Float(sparseWidth)
        let scaleY = Float(height) / Float(sparseHeight)

        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                // Map to sparse coordinates (nearest neighbor)
                let sx = Int(Float(x) / scaleX)
                let sy = Int(Float(y) / scaleY)

                // Search small radius for nearest valid depth point
                var foundDepth: Float = -1
                let searchRadius = 3

                searchLoop: for dy in -searchRadius...searchRadius {
                    for dx in -searchRadius...searchRadius {
                        let ssx = sx + dx
                        let ssy = sy + dy
                        if ssx >= 0 && ssx < sparseWidth && ssy >= 0 && ssy < sparseHeight {
                            let depth = sparseDepth[ssy * sparseWidth + ssx]
                            if depth > 0 {
                                foundDepth = depth
                                break searchLoop
                            }
                        }
                    }
                }

                if foundDepth > 0 {
                    // Normalize height to 0-1 range
                    let normalizedHeight = (foundDepth - minHeight) / heightRange

                    // Convert to heat map color
                    let (r, g, b) = heightToColor(normalizedHeight: CGFloat(normalizedHeight))

                    let pixelIndex = (y * width + x) * 4
                    pixels[pixelIndex] = UInt8(r * 255)
                    pixels[pixelIndex + 1] = UInt8(g * 255)
                    pixels[pixelIndex + 2] = UInt8(b * 255)
                    pixels[pixelIndex + 3] = 255
                }
            }
        }

        // Create CGImage from pixel data
        guard let providerRef = CGDataProvider(data: Data(pixels) as CFData) else { return nil }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    private func cropImageToWorkspace(_ image: UIImage, workspaceBounds: CGRect) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        // Ensure bounds are within image bounds
        let imageBounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let clampedBounds = workspaceBounds.intersection(imageBounds)

        guard !clampedBounds.isEmpty else { return image }

        // Convert from UIImage coordinates to CGImage coordinates (may need scaling for retina)
        let scale = image.scale
        let cropRect = CGRect(
            x: clampedBounds.origin.x * scale,
            y: clampedBounds.origin.y * scale,
            width: clampedBounds.width * scale,
            height: clampedBounds.height * scale
        )

        // Crop the image
        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        }

        return image
    }

    private func heightToColor(normalizedHeight: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        // Heat map: Blue (low) -> Cyan -> Green -> Yellow -> Red (high)
        let h = max(0, min(1, normalizedHeight))

        if h < 0.25 {
            // Blue to Cyan
            let t = h / 0.25
            return (0, t, 1)
        } else if h < 0.5 {
            // Cyan to Green
            let t = (h - 0.25) / 0.25
            return (0, 1, 1 - t)
        } else if h < 0.75 {
            // Green to Yellow
            let t = (h - 0.5) / 0.25
            return (t, 1, 0)
        } else {
            // Yellow to Red
            let t = (h - 0.75) / 0.25
            return (1, 1 - t, 0)
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

// MARK: - Compact Detection Status Panel (Top HUD)
struct CompactDetectionStatusPanel: View {
    let status: ManualCaptureView.DetectionStatus
    let mode: ManualCaptureView.CaptureMode

    var body: some View {
        let distanceGood = status.distanceToPlane >= 60 && status.distanceToPlane <= 100
        let angleGood = status.angleToPlane < 15

        return HStack(spacing: 8) {
            // Plane status
            CompactStatusBadge(
                icon: "cube.transparent",
                value: status.planeDetected ? "✓" : "⊘",
                isGood: status.planeDetected
            )

            // Distance (when plane detected)
            if status.planeDetected {
                CompactStatusBadge(
                    icon: "arrow.up.and.down",
                    value: String(format: "%.0f cm", status.distanceToPlane),
                    isGood: distanceGood
                )

                // Angle
                CompactStatusBadge(
                    icon: "angle",
                    value: String(format: "%.0f°", status.angleToPlane),
                    isGood: angleGood
                )
            }

            // Markers (auto mode only)
            if mode == .automatic {
                CompactStatusBadge(
                    icon: "qrcode",
                    value: "\(status.arucoMarkersDetected)/4",
                    isGood: status.arucoMarkersDetected >= 4
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - Compact Status Badge (for HUD)
struct CompactStatusBadge: View {
    let icon: String
    let value: String
    let isGood: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isGood ? .green : .orange)

            Text(value)
                .font(.caption2.bold())
                .foregroundColor(isGood ? .green : .orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - Compact Guide View (Top HUD)
struct CompactGuideView: View {
    let cornerCount: Int
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)

            Text(guideText)
                .font(.caption.weight(.medium))
                .foregroundColor(.white)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    private var guideText: String {
        switch cornerCount {
        case 0:
            return "Align reticle with corner, then tap +"
        case 1:
            return "Corner 1/4 placed - tap for next"
        case 2:
            return "Corner 2/4 placed - tap for next"
        case 3:
            return "Corner 3/4 placed - tap for final"
        default:
            return "All corners placed!"
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

// MARK: - Button Styles
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Processing View
struct ProcessingView: View {
    let statusMessage: String
    let progress: Double // 0.0 to 1.0

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.6),
                    Color.pink.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .blur(radius: 100)

            // Glass morphism effect
            ZStack {
                VStack(spacing: 30) {
                    // Animated icon
                    ZStack {
                        // Rotating rings
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.white.opacity(0.8), .white.opacity(0.2)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                                .frame(width: 80 + CGFloat(index * 30), height: 80 + CGFloat(index * 30))
                                .rotationEffect(.degrees(Double(index) * 120))
                                .animation(
                                    Animation.linear(duration: 3.0 - Double(index) * 0.5)
                                        .repeatForever(autoreverses: false),
                                    value: index
                                )
                        }

                        // Center icon
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.5), radius: 10)
                    }

                    // Status text
                    VStack(spacing: 12) {
                        Text(statusMessage)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2)

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 6)

                                // Progress
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.white, .white.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            }
                        }
                        .frame(width: 200, height: 6)

                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(50)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.1))
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.3), radius: 30)
            }
        }
    }
}
