import UIKit
import Vision
import CoreImage
import Accelerate
import simd

/// Implements RGB-D sensor fusion to blend camera visual data with LiDAR depth data
/// for enhanced depth perception and accuracy. Uses edge-aware interpolation to
/// preserve depth discontinuities at object boundaries.
class SensorFusionProcessor {

    struct FusedDepthResult {
        let depthPoints: [EnhancedDepthPoint]
        let confidenceMap: [Float]  // Per-point confidence (0-1)
        let edgeMap: [UInt8]  // Edge detection from RGB (0-255)
    }

    struct EnhancedDepthPoint {
        let position: simd_float3
        let pixelX: Int
        let pixelY: Int
        let confidence: Float  // 0-1, higher is better
        let rgbColor: (UInt8, UInt8, UInt8)  // Color from camera
        let edgeStrength: Float  // 0-1, from RGB edge detection
    }

    /// Fuses RGB camera image with LiDAR depth data to create enhanced depth map
    /// - Parameters:
    ///   - rgbImage: Camera image (UIImage)
    ///   - depthPoints: Sparse LiDAR depth points
    ///   - depthMapSize: Size of depth map
    ///   - imageSize: Size of RGB image
    ///   - minDepthChange: Minimum depth change to detect (in meters, default 0.01 = 1cm)
    func fuseRGBWithDepth(
        rgbImage: UIImage,
        depthPoints: [LiDARCaptureManager.DepthPoint],
        depthMapSize: CGSize,
        imageSize: CGSize,
        minDepthChange: Float = 0.01  // 1cm threshold
    ) -> FusedDepthResult? {

        guard let cgImage = rgbImage.cgImage else { return nil }

        // Step 1: Extract edges from RGB image using Vision framework
        print("🔀 Sensor Fusion: Extracting edges from RGB image...")
        let edgeMap = extractEdges(from: cgImage, targetSize: depthMapSize)

        // Step 2: Align depth points with RGB pixels and extract color
        print("🔀 Sensor Fusion: Aligning depth with RGB colors...")
        let enhancedPoints = alignDepthWithRGB(
            depthPoints: depthPoints,
            rgbImage: cgImage,
            edgeMap: edgeMap,
            depthMapSize: depthMapSize,
            imageSize: imageSize
        )

        // Step 3: Compute confidence based on edge alignment and depth consistency
        print("🔀 Sensor Fusion: Computing depth confidence...")
        let confidenceMap = computeConfidenceMap(
            enhancedPoints: enhancedPoints,
            depthMapSize: depthMapSize,
            minDepthChange: minDepthChange
        )

        print("🔀 Sensor Fusion: Complete - \(enhancedPoints.count) enhanced points")

        return FusedDepthResult(
            depthPoints: enhancedPoints,
            confidenceMap: confidenceMap,
            edgeMap: edgeMap
        )
    }

    /// Extract edges from RGB image using edge detection
    private func extractEdges(from cgImage: CGImage, targetSize: CGSize) -> [UInt8] {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        // Convert to grayscale
        guard let grayscale = convertToGrayscale(cgImage, width: width, height: height) else {
            return [UInt8](repeating: 0, count: width * height)
        }

        // Apply Sobel edge detection (faster than Canny)
        let edgeMap = sobelEdgeDetection(grayscale, width: width, height: height)

        return edgeMap
    }

    /// Convert image to grayscale
    private func convertToGrayscale(_ cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        var grayscale = [UInt8](repeating: 0, count: width * height)

        let context = CGContext(
            data: &grayscale,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return grayscale
    }

    /// Fast Sobel edge detection
    private func sobelEdgeDetection(_ input: [UInt8], width: Int, height: Int) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: width * height)

        // Sobel kernels
        let sobelX: [Int] = [-1, 0, 1, -2, 0, 2, -1, 0, 1]
        let sobelY: [Int] = [-1, -2, -1, 0, 0, 0, 1, 2, 1]

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var gx: Int = 0
                var gy: Int = 0

                // Apply 3x3 Sobel kernels
                for ky in -1...1 {
                    for kx in -1...1 {
                        let idx = (y + ky) * width + (x + kx)
                        let kernelIdx = (ky + 1) * 3 + (kx + 1)
                        let pixelValue = Int(input[idx])

                        gx += pixelValue * sobelX[kernelIdx]
                        gy += pixelValue * sobelY[kernelIdx]
                    }
                }

                // Gradient magnitude
                let magnitude = sqrt(Float(gx * gx + gy * gy))
                output[y * width + x] = UInt8(min(255, magnitude))
            }
        }

        return output
    }

    /// Align depth points with RGB image and extract color + edge info
    private func alignDepthWithRGB(
        depthPoints: [LiDARCaptureManager.DepthPoint],
        rgbImage: CGImage,
        edgeMap: [UInt8],
        depthMapSize: CGSize,
        imageSize: CGSize
    ) -> [EnhancedDepthPoint] {

        let rgbWidth = rgbImage.width
        let rgbHeight = rgbImage.height
        let depthWidth = Int(depthMapSize.width)
        let depthHeight = Int(depthMapSize.height)

        // Extract RGB pixel data
        guard let rgbData = extractRGBData(from: rgbImage) else {
            // Fallback: create enhanced points without RGB data
            return depthPoints.map { point in
                let edgeIdx = point.pixelY * depthWidth + point.pixelX
                let edgeStrength = edgeIdx < edgeMap.count ? Float(edgeMap[edgeIdx]) / 255.0 : 0.0

                return EnhancedDepthPoint(
                    position: point.position,
                    pixelX: point.pixelX,
                    pixelY: point.pixelY,
                    confidence: point.confidence == .high ? 1.0 : (point.confidence == .medium ? 0.7 : 0.3),
                    rgbColor: (128, 128, 128),
                    edgeStrength: edgeStrength
                )
            }
        }

        var enhancedPoints: [EnhancedDepthPoint] = []

        for point in depthPoints {
            // Map depth pixel to RGB pixel
            let rgbX = Int(Float(point.pixelX) * Float(rgbWidth) / Float(depthWidth))
            let rgbY = Int(Float(point.pixelY) * Float(rgbHeight) / Float(depthHeight))

            guard rgbX >= 0 && rgbX < rgbWidth && rgbY >= 0 && rgbY < rgbHeight else {
                continue
            }

            // Extract RGB color
            let rgbIdx = (rgbY * rgbWidth + rgbX) * 4
            let r = rgbData[rgbIdx]
            let g = rgbData[rgbIdx + 1]
            let b = rgbData[rgbIdx + 2]

            // Get edge strength at this location
            let edgeIdx = point.pixelY * depthWidth + point.pixelX
            let edgeStrength = edgeIdx < edgeMap.count ? Float(edgeMap[edgeIdx]) / 255.0 : 0.0

            // Convert ARKit confidence to numeric
            let baseConfidence: Float
            switch point.confidence {
            case .high:
                baseConfidence = 1.0
            case .medium:
                baseConfidence = 0.7
            case .low:
                baseConfidence = 0.3
            @unknown default:
                baseConfidence = 0.5
            }

            // Boost confidence at edges (where depth discontinuities are expected)
            let confidenceBoost = edgeStrength * 0.2
            let finalConfidence = min(1.0, baseConfidence + confidenceBoost)

            enhancedPoints.append(EnhancedDepthPoint(
                position: point.position,
                pixelX: point.pixelX,
                pixelY: point.pixelY,
                confidence: finalConfidence,
                rgbColor: (r, g, b),
                edgeStrength: edgeStrength
            ))
        }

        return enhancedPoints
    }

    /// Extract RGBA pixel data from CGImage
    private func extractRGBData(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixels
    }

    /// Compute confidence map based on depth consistency and edge alignment
    private func computeConfidenceMap(
        enhancedPoints: [EnhancedDepthPoint],
        depthMapSize: CGSize,
        minDepthChange: Float
    ) -> [Float] {

        let width = Int(depthMapSize.width)
        let height = Int(depthMapSize.height)
        var confidenceMap = [Float](repeating: 0.0, count: width * height)

        // Fill confidence map from enhanced points
        for point in enhancedPoints {
            if point.pixelX >= 0 && point.pixelX < width && point.pixelY >= 0 && point.pixelY < height {
                let idx = point.pixelY * width + point.pixelX
                confidenceMap[idx] = point.confidence
            }
        }

        // Check depth consistency in local neighborhoods
        for point in enhancedPoints {
            let x = point.pixelX
            let y = point.pixelY

            guard x >= 1 && x < width - 1 && y >= 1 && y < height - 1 else { continue }

            // Check 3x3 neighborhood for depth consistency
            var depthVariation: Float = 0.0
            var neighborCount = 0

            for dy in -1...1 {
                for dx in -1...1 {
                    if dx == 0 && dy == 0 { continue }

                    let nx = x + dx
                    let ny = y + dy

                    // Find nearby point
                    if let neighbor = enhancedPoints.first(where: { $0.pixelX == nx && $0.pixelY == ny }) {
                        let depthDiff = abs(point.position.z - neighbor.position.z)
                        depthVariation += depthDiff
                        neighborCount += 1
                    }
                }
            }

            // If depth is consistent (low variation), boost confidence
            if neighborCount > 0 {
                let avgVariation = depthVariation / Float(neighborCount)

                let idx = y * width + x
                if avgVariation < minDepthChange {
                    // Smooth region - boost confidence
                    confidenceMap[idx] = min(1.0, confidenceMap[idx] + 0.1)
                } else if avgVariation > minDepthChange * 3.0 && point.edgeStrength > 0.5 {
                    // High variation at edge - this is expected, maintain confidence
                    confidenceMap[idx] = max(confidenceMap[idx], 0.8)
                }
            }
        }

        return confidenceMap
    }

    /// Convert enhanced depth points back to standard depth points (for compatibility)
    func convertToStandardDepthPoints(_ enhancedPoints: [EnhancedDepthPoint]) -> [LiDARCaptureManager.DepthPoint] {
        return enhancedPoints.map { enhanced in
            let confidence: ARConfidenceLevel
            if enhanced.confidence >= 0.8 {
                confidence = .high
            } else if enhanced.confidence >= 0.5 {
                confidence = .medium
            } else {
                confidence = .low
            }

            return LiDARCaptureManager.DepthPoint(
                position: enhanced.position,
                confidence: confidence,
                pixelX: enhanced.pixelX,
                pixelY: enhanced.pixelY
            )
        }
    }
}
