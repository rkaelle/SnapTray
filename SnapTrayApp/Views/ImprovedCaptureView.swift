import SwiftUI
import ARKit

struct ImprovedCaptureView: View {
    let onCaptureDone: (Project) -> Void
    let onCancel: () -> Void

    @StateObject private var lidarManager = LiDARCaptureManager()
    @State private var isProcessing = false
    @State private var statusMessage = "Initializing LiDAR..."
    @State private var showGuide = true
    @State private var showTroubleshooting = false
    @State private var detectionAttempts = 0
    @State private var scanTimer: Timer?

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
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel")
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }

                    Spacer()

                    // Detection status
                    HStack(spacing: 8) {
                        if lidarManager.isCapturing {
                            if lidarManager.detectedPlane != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Ready to scan")
                                    .foregroundColor(.white)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Finding surface...")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                }
                .padding()

                Spacer()

                // Quick guide overlay
                if showGuide {
                    QuickGuideOverlay(onDismiss: { showGuide = false })
                }

                // Troubleshooting overlay
                if showTroubleshooting {
                    TroubleshootingOverlay(onDismiss: { showTroubleshooting = false })
                }

                Spacer()

                // Status messages and tips
                VStack(spacing: 12) {
                    // Main status
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)

                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)

                    // Helpful tip if no plane detected for a while
                    if lidarManager.isCapturing && lidarManager.detectedPlane == nil && detectionAttempts > 3 {
                        Button(action: { showTroubleshooting = true }) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                Text("Having trouble? Tap for help")
                            }
                            .font(.caption)
                            .padding(8)
                            .background(Color.orange.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()

                // Capture button
                Button(action: performCapture) {
                    ZStack {
                        Circle()
                            .stroke(buttonBorderColor, lineWidth: 4)
                            .frame(width: 80, height: 80)

                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(isProcessing || lidarManager.detectedPlane == nil)
                .opacity((isProcessing || lidarManager.detectedPlane == nil) ? 0.5 : 1.0)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            lidarManager.startSession()
            startDetectionMonitoring()
        }
        .onDisappear {
            lidarManager.stopSession()
            scanTimer?.invalidate()
        }
    }

    private var statusIcon: String {
        if lidarManager.detectedPlane != nil {
            return "checkmark.circle.fill"
        } else if lidarManager.isCapturing {
            return "scope"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        if lidarManager.detectedPlane != nil {
            return .green
        } else if lidarManager.isCapturing {
            return .yellow
        } else {
            return .red
        }
    }

    private var buttonBorderColor: Color {
        lidarManager.detectedPlane != nil ? .green : .gray
    }

    private func startDetectionMonitoring() {
        scanTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if lidarManager.detectedPlane == nil {
                detectionAttempts += 1
                updateStatusMessage()
            } else {
                detectionAttempts = 0
                statusMessage = "Surface detected - ready to scan!"
            }
        }
    }

    private func updateStatusMessage() {
        let messages = [
            "Move phone slowly up or down",
            "Ensure background is visible and flat",
            "Try adjusting lighting",
            "Make sure surface isn't too dark or reflective"
        ]
        statusMessage = messages[min(detectionAttempts - 1, messages.count - 1)]
    }

    private func performCapture() {
        isProcessing = true
        statusMessage = "Capturing... hold steady"

        lidarManager.captureFrame()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processCapture()
        }
    }

    private func processCapture() {
        guard let captured = lidarManager.capturedFrame,
              let plane = lidarManager.detectedPlane else {
            statusMessage = "Capture failed - please try again"
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

        statusMessage = "Scan complete!"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProcessing = false
            onCaptureDone(project)
        }
    }
}

struct QuickGuideOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Quick Scan Guide")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                GuideStep(number: 1, text: "Place 4 fiducial markers at corners")
                GuideStep(number: 2, text: "Arrange tools flat on dark background")
                GuideStep(number: 3, text: "Hold phone 60-100cm (2-3 ft) above")
                GuideStep(number: 4, text: "Keep phone parallel to surface")
                GuideStep(number: 5, text: "Wait for green \"Ready\" indicator")
            }

            Button(action: onDismiss) {
                Text("Got it!")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(8)
            }
            .padding(.top, 5)
        }
        .padding(20)
        .background(Color.black.opacity(0.85))
        .cornerRadius(15)
        .padding(.horizontal, 30)
    }
}

struct TroubleshootingOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Troubleshooting")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                TroubleshootTip(icon: "lightbulb.fill", text: "Improve lighting - use diffuse overhead light")
                TroubleshootTip(icon: "square.fill", text: "Use a darker, matte background")
                TroubleshootTip(icon: "move.3d", text: "Move phone slowly up/down to help detection")
                TroubleshootTip(icon: "level.fill", text: "Keep phone more level (parallel to surface)")
                TroubleshootTip(icon: "arrow.up.and.down", text: "Try different height (50cm-120cm)")
            }

            Button(action: onDismiss) {
                Text("Close")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(8)
            }
            .padding(.top, 5)
        }
        .padding(20)
        .background(Color.orange.opacity(0.9))
        .cornerRadius(15)
        .padding(.horizontal, 30)
    }
}

struct TroubleshootTip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GuideStep: View {
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
