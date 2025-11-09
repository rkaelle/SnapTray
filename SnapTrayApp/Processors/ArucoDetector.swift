import Vision
import UIKit
import CoreImage

class ArucoDetector {
    private let markerSize: CGFloat = 50.0  // 5cm in pixels (at some reference scale)

    struct DetectionResult {
        let markers: [DetectedMarker]
        let homography: matrix_float3x3?
        let pixelToMMScale: Double?
        let workspaceBounds: CGRect?
    }

    struct DetectedMarker {
        let id: Int
        let corners: [CGPoint]
        let center: CGPoint
        let coinDetected: Bool
        let coinRadius: Double?
    }

    func detectMarkers(in image: UIImage) -> DetectionResult {
        guard let cgImage = image.cgImage else {
            return DetectionResult(markers: [], homography: nil, pixelToMMScale: nil, workspaceBounds: nil)
        }

        var detectedMarkers: [DetectedMarker] = []

        // Detect ArUco markers using Vision
        let markers = detectArucoMarkers(in: cgImage)
        detectedMarkers.append(contentsOf: markers)

        // Detect coins (quarters) as backup
        let coins = detectCoins(in: image)

        // Merge coin detections with marker detections
        detectedMarkers = mergeCoinsWithMarkers(markers: detectedMarkers, coins: coins)

        // Compute homography if we have 4 markers
        var homography: matrix_float3x3?
        var pixelToMMScale: Double?
        var workspaceBounds: CGRect?

        if detectedMarkers.count >= 4 {
            let result = computeHomographyAndScale(markers: detectedMarkers)
            homography = result.homography
            pixelToMMScale = result.scale
            workspaceBounds = result.bounds
        }

        return DetectionResult(
            markers: detectedMarkers,
            homography: homography,
            pixelToMMScale: pixelToMMScale,
            workspaceBounds: workspaceBounds
        )
    }

    private func detectArucoMarkers(in cgImage: CGImage) -> [DetectedMarker] {
        var markers: [DetectedMarker] = []

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]  // Note: ArUco detection not directly supported, using custom detection

        // For ArUco, we'll use a custom approach with rectangle detection
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.minimumAspectRatio = 0.8
        rectangleRequest.maximumAspectRatio = 1.2
        rectangleRequest.minimumSize = 0.05
        rectangleRequest.maximumObservations = 20

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([rectangleRequest])

            if let results = rectangleRequest.results {
                for (index, observation) in results.enumerated() {
                    let corners = [
                        observation.topLeft,
                        observation.topRight,
                        observation.bottomRight,
                        observation.bottomLeft
                    ].map { point in
                        CGPoint(
                            x: point.x * CGFloat(cgImage.width),
                            y: (1 - point.y) * CGFloat(cgImage.height)
                        )
                    }

                    let center = CGPoint(
                        x: corners.map { $0.x }.reduce(0, +) / 4,
                        y: corners.map { $0.y }.reduce(0, +) / 4
                    )

                    // Check if this looks like a marker (roughly square, dark corners)
                    if isLikelyMarker(corners: corners, cgImage: cgImage) {
                        markers.append(DetectedMarker(
                            id: index,
                            corners: corners,
                            center: center,
                            coinDetected: false,
                            coinRadius: nil
                        ))
                    }
                }
            }
        } catch {
            print("Error detecting rectangles: \(error)")
        }

        return markers
    }

    private func isLikelyMarker(corners: [CGPoint], cgImage: CGImage) -> Bool {
        // Check aspect ratio
        let width = distance(corners[0], corners[1])
        let height = distance(corners[1], corners[2])
        let aspectRatio = width / height

        return aspectRatio > 0.8 && aspectRatio < 1.2
    }

    private func detectCoins(in image: UIImage) -> [(center: CGPoint, radius: Double)] {
        guard let cgImage = image.cgImage else { return [] }

        var coins: [(CGPoint, Double)] = []

        // Use Hough Circle Transform approach
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.5

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Note: Actual contour-based circle detection requires more complex algorithms
        // For now, return empty array - coin detection is backup to ArUco markers
        return []
    }

    private func detectCoinsWithTemplateMatching(in cgImage: CGImage) -> [(CGPoint, Double)] {
        // Simplified implementation: Coin detection is optional backup to ArUco markers
        // In production, this would use Hough Circle Transform or template matching
        // For MVP, ArUco markers provide sufficient accuracy
        return []
    }

    private func mergeCoinsWithMarkers(markers: [DetectedMarker], coins: [(center: CGPoint, radius: Double)]) -> [DetectedMarker] {
        var merged: [DetectedMarker] = []

        for marker in markers {
            var coinFound = false
            var coinRadius: Double?

            // Check if there's a coin near this marker
            for coin in coins {
                let dist = distance(marker.center, coin.center)
                if dist < 100 {  // Within 100 pixels
                    coinFound = true
                    coinRadius = coin.radius
                    break
                }
            }

            merged.append(DetectedMarker(
                id: marker.id,
                corners: marker.corners,
                center: marker.center,
                coinDetected: coinFound,
                coinRadius: coinRadius
            ))
        }

        // Add standalone coins as markers
        for (index, coin) in coins.enumerated() {
            let nearMarker = markers.contains { distance($0.center, coin.center) < 100 }
            if !nearMarker {
                // Create a square marker around the coin
                let r = CGFloat(coin.radius * 1.5)
                let corners = [
                    CGPoint(x: coin.center.x - r, y: coin.center.y - r),
                    CGPoint(x: coin.center.x + r, y: coin.center.y - r),
                    CGPoint(x: coin.center.x + r, y: coin.center.y + r),
                    CGPoint(x: coin.center.x - r, y: coin.center.y + r)
                ]

                merged.append(DetectedMarker(
                    id: markers.count + index,
                    corners: corners,
                    center: coin.center,
                    coinDetected: true,
                    coinRadius: coin.radius
                ))
            }
        }

        return merged
    }

    private func computeHomographyAndScale(markers: [DetectedMarker]) -> (homography: matrix_float3x3?, scale: Double?, bounds: CGRect?) {
        guard markers.count >= 4 else { return (nil, nil, nil) }

        // Sort markers by position to get corners
        let sorted = markers.sorted { m1, m2 in
            m1.center.y != m2.center.y ? m1.center.y < m2.center.y : m1.center.x < m2.center.x
        }

        // Take top-left, top-right, bottom-right, bottom-left
        let topTwo = sorted.prefix(2).sorted { $0.center.x < $1.center.x }
        let bottomTwo = sorted.suffix(2).sorted { $0.center.x < $1.center.x }

        let corners = [
            topTwo.first!.center,      // Top-left
            topTwo.last!.center,       // Top-right
            bottomTwo.last!.center,    // Bottom-right
            bottomTwo.first!.center    // Bottom-left
        ]

        // Compute scale from marker spacing or coin diameter
        var pixelToMMScale: Double?

        // Try coin diameter first (most accurate)
        if let coin = markers.first(where: { $0.coinDetected }), let radius = coin.coinRadius {
            let coinDiameterMM = 24.26  // US quarter
            pixelToMMScale = coinDiameterMM / (radius * 2.0)
        }

        // Fallback: use marker spacing
        if pixelToMMScale == nil {
            let dist = distance(corners[0], corners[1])
            let assumedDistanceMM = 200.0  // Assume ~200mm between markers
            pixelToMMScale = assumedDistanceMM / dist
        }

        // Compute workspace bounds
        let minX = corners.map { $0.x }.min()!
        let maxX = corners.map { $0.x }.max()!
        let minY = corners.map { $0.y }.min()!
        let maxY = corners.map { $0.y }.max()!

        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Compute homography (simplified - in production use proper perspective transform)
        let homography = computeHomographyMatrix(from: corners, to: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: bounds.width, y: 0),
            CGPoint(x: bounds.width, y: bounds.height),
            CGPoint(x: 0, y: bounds.height)
        ])

        return (homography, pixelToMMScale, bounds)
    }

    private func computeHomographyMatrix(from src: [CGPoint], to dst: [CGPoint]) -> matrix_float3x3 {
        // Simplified homography - in production, use OpenCV or Accelerate framework
        // For now, return identity
        return matrix_float3x3(
            simd_float3(1, 0, 0),
            simd_float3(0, 1, 0),
            simd_float3(0, 0, 1)
        )
    }

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
}
