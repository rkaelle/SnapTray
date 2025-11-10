import ARKit
import RealityKit
import Combine
import UIKit

class LiDARCaptureManager: NSObject, ObservableObject {
    @Published var capturedFrame: CapturedFrame?
    @Published var isCapturing = false
    @Published var detectedPlane: DetectedPlane?
    @Published var workspaceBounds: CGRect?
    // Shared AR session exposed for ARSCNView binding
    let arSession: ARSession = ARSession()
    private var isSessionRunning = false

    struct CapturedFrame {
        let image: UIImage
        let depthData: [DepthPoint]
        let cameraTransform: matrix_float4x4
        let timestamp: TimeInterval
    }

    struct DepthPoint {
        let position: simd_float3  // 3D position in world space
        let confidence: ARConfidenceLevel
    }

    struct DetectedPlane {
        let normal: simd_float3
        let center: simd_float3
        let transform: matrix_float4x4
        let inlierCount: Int
    }

    func startSession() {
        if isSessionRunning { 
            print("AR session already running; ignoring startSession()")
            return
        }

        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("LiDAR not supported on this device")
            DispatchQueue.main.async {
                self.isCapturing = false
            }
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.frameSemantics = .sceneDepth

        DispatchQueue.main.async {
            self.arSession.delegate = self
            self.arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            self.isSessionRunning = true
            self.isCapturing = true
        }
    }

    func stopSession() {
        arSession.pause()
        isSessionRunning = false
        isCapturing = false
    }

    func captureFrame() {
        guard let frame = arSession.currentFrame else { return }

        // Get RGB image
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        // Extract depth data
        var depthPoints: [DepthPoint] = []
        if let depthMap = frame.sceneDepth?.depthMap,
           let confidenceMap = frame.sceneDepth?.confidenceMap {
            depthPoints = extractDepthPoints(from: depthMap, confidence: confidenceMap, frame: frame)
        }

        let captured = CapturedFrame(
            image: image,
            depthData: depthPoints,
            cameraTransform: frame.camera.transform,
            timestamp: frame.timestamp
        )

        DispatchQueue.main.async {
            self.capturedFrame = captured
        }

        // Detect plane
        if let plane = detectPlaneRANSAC(from: depthPoints) {
            DispatchQueue.main.async {
                self.detectedPlane = plane
            }
        }
    }

    private func extractDepthPoints(from depthMap: CVPixelBuffer, confidence: CVPixelBuffer, frame: ARFrame) -> [DepthPoint] {
        var points: [DepthPoint] = []

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        CVPixelBufferLockBaseAddress(confidence, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            CVPixelBufferUnlockBaseAddress(confidence, .readOnly)
        }

        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        let depthPointer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthMap), to: UnsafeMutablePointer<Float32>.self)
        let confidencePointer = unsafeBitCast(CVPixelBufferGetBaseAddress(confidence), to: UnsafeMutablePointer<UInt8>.self)

        let camera = frame.camera
        let viewMatrix = camera.viewMatrix(for: .portrait)
        let intrinsics = camera.intrinsics

        // Sample every 6th pixel for performance
        let pixelStride = 6

        for y in stride(from: 0, to: depthHeight, by: pixelStride) {
            for x in stride(from: 0, to: depthWidth, by: pixelStride) {
                let index = y * depthWidth + x
                let depth = depthPointer[index]
                let conf = confidencePointer[index]

                guard depth > 0, depth < 10.0 else { continue }  // Valid depth range

                let confidenceLevel: ARConfidenceLevel
                switch conf {
                case 0: confidenceLevel = .low
                case 1: confidenceLevel = .medium
                case 2: confidenceLevel = .high
                default: confidenceLevel = .low
                }

                // Only use medium/high confidence points
                guard confidenceLevel != .low else { continue }

                // Convert pixel coordinates to camera space
                let xNorm = (Float(x) - intrinsics[2][0]) / intrinsics[0][0]
                let yNorm = (Float(y) - intrinsics[2][1]) / intrinsics[1][1]

                let pointInCamera = simd_float3(xNorm * depth, yNorm * depth, -depth)

                // Transform to world space
                let viewMatrixInv = simd_inverse(viewMatrix)
                let pointInWorld = (viewMatrixInv * simd_float4(pointInCamera, 1.0))

                points.append(DepthPoint(
                    position: simd_float3(pointInWorld.x, pointInWorld.y, pointInWorld.z),
                    confidence: confidenceLevel
                ))
            }
        }

        return points
    }

    private func detectPlaneRANSAC(from points: [DepthPoint], iterations: Int = 100, threshold: Float = 0.01) -> DetectedPlane? {
        guard points.count >= 3 else { return nil }

        var bestPlane: (normal: simd_float3, center: simd_float3, inliers: Int)?

        for _ in 0..<iterations {
            // Sample 3 random points
            let samples = (0..<3).map { _ in points.randomElement()!.position }

            // Compute plane from 3 points
            let v1 = samples[1] - samples[0]
            let v2 = samples[2] - samples[0]
            var normal = simd_normalize(simd_cross(v1, v2))

            // Ensure normal points up (positive Y in ARKit)
            if normal.y < 0 {
                normal = -normal
            }

            let d = -simd_dot(normal, samples[0])

            // Count inliers
            var inliers = 0
            var inlierPoints: [simd_float3] = []

            for point in points {
                let distance = abs(simd_dot(normal, point.position) + d)
                if distance < threshold {
                    inliers += 1
                    inlierPoints.append(point.position)
                }
            }

            // Update best plane
            if bestPlane == nil || inliers > bestPlane!.inliers {
                let center = inlierPoints.reduce(simd_float3.zero, +) / Float(inlierPoints.count)
                bestPlane = (normal, center, inliers)
            }
        }

        guard let plane = bestPlane, plane.inliers > points.count / 4 else { return nil }

        // Create transform matrix for the plane
        let up = plane.normal
        let right = simd_normalize(simd_cross(simd_float3(0, 0, 1), up))
        let forward = simd_cross(up, right)

        let transform = matrix_float4x4(
            simd_float4(right, 0),
            simd_float4(up, 0),
            simd_float4(forward, 0),
            simd_float4(plane.center, 1)
        )

        return DetectedPlane(
            normal: plane.normal,
            center: plane.center,
            transform: transform,
            inlierCount: plane.inliers
        )
    }

    func projectPointsToPlane(points: [DepthPoint], plane: DetectedPlane) -> [CGPoint] {
        let planeInverse = simd_inverse(plane.transform)
        var projectedPoints: [CGPoint] = []

        for point in points {
            // Transform to plane space
            let localPoint = planeInverse * simd_float4(point.position, 1.0)

            // Project to 2D (X, Z in plane space becomes X, Y in 2D)
            projectedPoints.append(CGPoint(x: Double(localPoint.x), y: Double(localPoint.z)))
        }

        return projectedPoints
    }

    func getDepthAtContour(contour: [CGPoint], plane: DetectedPlane, allPoints: [DepthPoint]) -> [Float] {
        var depths: [Float] = []

        for point in allPoints {
            // Check if point is inside contour
            let projected = projectPointToPlane(point: point.position, plane: plane)

            if isPointInPolygon(point: projected, polygon: contour) {
                let heightAbovePlane = simd_dot(point.position - plane.center, plane.normal)
                depths.append(heightAbovePlane)
            }
        }

        return depths
    }

    private func projectPointToPlane(point: simd_float3, plane: DetectedPlane) -> CGPoint {
        let planeInverse = simd_inverse(plane.transform)
        let localPoint = planeInverse * simd_float4(point, 1.0)
        return CGPoint(x: Double(localPoint.x), y: Double(localPoint.z))
    }

    private func isPointInPolygon(point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count > 2 else { return false }

        var inside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) &&
               (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x) {
                inside.toggle()
            }
            j = i
        }

        return inside
    }
}

extension LiDARCaptureManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Do not retain frames. If future live processing is needed, throttle it here without storing ARFrame.
    }
}
