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
        rectangleRequest.minimumAspectRatio = 0.7  // More lenient
        rectangleRequest.maximumAspectRatio = 1.3  // More lenient
        rectangleRequest.minimumSize = 0.02  // Detect smaller rectangles
        rectangleRequest.minimumConfidence = 0.4  // Lower confidence threshold
        rectangleRequest.maximumObservations = 30  // Check more rectangles

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

    // Known ArUco 4x4 patterns (Dictionary 50, IDs 0-3)
    private let arucoPatterns: [[Int]] = [
        // ID 0
        [0, 1, 1, 0,
         1, 0, 1, 1,
         0, 1, 0, 0,
         0, 1, 1, 1],
        // ID 1
        [1, 0, 0, 1,
         0, 1, 0, 0,
         1, 0, 1, 1,
         1, 1, 0, 0],
        // ID 2
        [1, 0, 1, 1,
         1, 1, 0, 1,
         0, 1, 0, 0,
         0, 0, 1, 0],
        // ID 3
        [0, 1, 0, 0,
         1, 1, 1, 0,
         1, 0, 0, 1,
         0, 0, 1, 1]
    ]

    private func isLikelyMarker(corners: [CGPoint], cgImage: CGImage) -> Bool {
        // Quick checks first
        let width = distance(corners[0], corners[1])
        let height = distance(corners[1], corners[2])
        let aspectRatio = width / height

        // Must be square-ish
        guard aspectRatio > 0.7 && aspectRatio < 1.3 else { return false }

        // Check size
        let area = width * height
        let imageArea = Double(cgImage.width * cgImage.height)
        let relativeArea = area / imageArea
        guard relativeArea > 0.001 && relativeArea < 0.3 else { return false }

        // Extract and check pattern
        guard let markerImage = extractMarkerRegion(corners: corners, from: cgImage, size: 8) else {
            return false
        }

        // Check for black border (ArUco requirement)
        if !hasBlackBorder(markerImage) {
            return false
        }

        // Try to decode inner 4x4 pattern
        let pattern = decodeInnerPattern(markerImage)

        // Check if pattern matches any known ArUco marker
        return matchesArucoPattern(pattern)
    }

    private func extractMarkerRegion(corners: [CGPoint], from cgImage: CGImage, size: Int) -> [[UInt8]]? {
        // Create a small 8x8 image by sampling the marker region
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8

        var grid = [[UInt8]](repeating: [UInt8](repeating: 0, count: size), count: size)

        // Sample points in a grid across the marker
        for y in 0..<size {
            for x in 0..<size {
                // Bilinear interpolation within the quadrilateral
                let u = Double(x) / Double(size - 1)
                let v = Double(y) / Double(size - 1)

                // Interpolate position in quadrilateral
                let top = CGPoint(
                    x: corners[0].x * (1 - u) + corners[1].x * u,
                    y: corners[0].y * (1 - u) + corners[1].y * u
                )
                let bottom = CGPoint(
                    x: corners[3].x * (1 - u) + corners[2].x * u,
                    y: corners[3].y * (1 - u) + corners[2].y * u
                )
                let point = CGPoint(
                    x: top.x * (1 - v) + bottom.x * v,
                    y: top.y * (1 - v) + bottom.y * v
                )

                // Sample pixel
                let px = Int(point.x)
                let py = Int(point.y)

                if px >= 0 && px < width && py >= 0 && py < height {
                    let offset = py * width * bytesPerPixel + px * bytesPerPixel
                    let intensity = bytes[offset]
                    grid[y][x] = intensity
                }
            }
        }

        return grid
    }

    private func hasBlackBorder(_ grid: [[UInt8]]) -> Bool {
        let size = grid.count
        guard size == 8 else { return false }

        // Check if outer ring is mostly black (< 100)
        var blackCount = 0
        var totalCount = 0

        // Top and bottom rows
        for x in 0..<size {
            if grid[0][x] < 100 { blackCount += 1 }
            if grid[size-1][x] < 100 { blackCount += 1 }
            totalCount += 2
        }

        // Left and right columns (excluding corners already counted)
        for y in 1..<(size-1) {
            if grid[y][0] < 100 { blackCount += 1 }
            if grid[y][size-1] < 100 { blackCount += 1 }
            totalCount += 2
        }

        // At least 70% of border should be black
        return Double(blackCount) / Double(totalCount) > 0.7
    }

    private func decodeInnerPattern(_ grid: [[UInt8]]) -> [Int] {
        // Extract inner 4x4 grid (skip border)
        var pattern = [Int]()

        for y in 0..<4 {
            for x in 0..<4 {
                // Map to grid coordinates (border is cells 0,1 and 6,7; inner is 2-5)
                let gridY = 2 + y
                let gridX = 2 + x

                // Average the cell
                let value = grid[gridY][gridX]

                // Threshold: >128 = white (1), <=128 = black (0)
                pattern.append(value > 128 ? 1 : 0)
            }
        }

        return pattern
    }

    private func matchesArucoPattern(_ pattern: [Int]) -> Bool {
        guard pattern.count == 16 else { return false }

        // Check all 4 rotations of the pattern
        for rotation in 0..<4 {
            let rotated = rotatePattern(pattern, times: rotation)

            // Check against all known patterns
            for knownPattern in arucoPatterns {
                if rotated == knownPattern {
                    return true
                }
            }
        }

        return false
    }

    private func rotatePattern(_ pattern: [Int], times: Int) -> [Int] {
        var result = pattern
        for _ in 0..<times {
            // Rotate 4x4 grid 90 degrees clockwise
            var rotated = [Int](repeating: 0, count: 16)
            for y in 0..<4 {
                for x in 0..<4 {
                    let oldIdx = y * 4 + x
                    let newIdx = x * 4 + (3 - y)
                    rotated[newIdx] = result[oldIdx]
                }
            }
            result = rotated
        }
        return result
    }

    private func detectCoins(in image: UIImage) -> [(center: CGPoint, radius: Double)] {
        // Note: Actual contour-based circle detection requires more complex algorithms
        // For now, return empty array - coin detection is backup to ArUco markers
        // In production, this would use Hough Circle Transform via Accelerate framework
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
