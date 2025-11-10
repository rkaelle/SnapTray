import UIKit
import Vision
import CoreImage
import Accelerate
import simd

class SegmentationProcessor {
    struct SegmentationResult {
        let contours: [Contour]
        let processedImage: UIImage?
    }

    struct Contour {
        let points: [CGPoint]
        let area: Double
        let boundingBox: CGRect
    }

    // Reuse CIContext to save memory
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // Project 3D world point to 2D image coordinates using camera projection
    private func project3DToImage(
        worldPoint: simd_float3,
        cameraTransform: matrix_float4x4,
        intrinsics: matrix_float3x3,
        imageSize: CGSize
    ) -> CGPoint? {
        // Transform to camera space
        let viewMatrix = simd_inverse(cameraTransform)
        let pointInCamera = viewMatrix * simd_float4(worldPoint, 1.0)

        // Check if behind camera
        if pointInCamera.z >= 0 { return nil }

        // Project to normalized coordinates
        let x = pointInCamera.x / -pointInCamera.z
        let y = pointInCamera.y / -pointInCamera.z

        // Apply intrinsics to get pixel coordinates
        let pixelX = x * intrinsics[0][0] + intrinsics[2][0]
        let pixelY = y * intrinsics[1][1] + intrinsics[2][1]

        // Check bounds
        if pixelX < 0 || pixelX >= Float(imageSize.width) ||
           pixelY < 0 || pixelY >= Float(imageSize.height) {
            return nil
        }

        return CGPoint(x: CGFloat(pixelX), y: CGFloat(pixelY))
    }

    // FAST: Use depth data to find tools above the plane
    func segmentToolsFromDepth(
        depthPoints: [LiDARCaptureManager.DepthPoint],
        plane: LiDARCaptureManager.DetectedPlane,
        cameraTransform: matrix_float4x4,
        cameraIntrinsics: matrix_float3x3,
        imageSize: CGSize,
        depthMapSize: CGSize,
        workspaceBounds: CGRect?,
        heightThreshold: Float = 0.005, // 5mm above plane
        progressCallback: ((String) -> Void)? = nil
    ) -> SegmentationResult {
        progressCallback?("Analyzing depth data...")

        // Use larger working size for better detail
        let workingWidth = 1024
        let workingHeight = Int(1024 * imageSize.height / imageSize.width)

        print("🎯 Depth detection setup:")
        print("   Image size: \(imageSize.width)x\(imageSize.height)")
        print("   Working size: \(workingWidth)x\(workingHeight)")
        print("   Depth map: \(depthMapSize.width)x\(depthMapSize.height)")
        print("   Height threshold: \(heightThreshold)m")

        var mask = [UInt8](repeating: 0, count: workingWidth * workingHeight)
        var pointsAbovePlane = 0

        // Direct proportional scale from depth map to working image
        let scaleX = CGFloat(workingWidth) / depthMapSize.width
        let scaleY = CGFloat(workingHeight) / depthMapSize.height

        print("   Scale factors: X=\(scaleX), Y=\(scaleY)")

        for point in depthPoints {
            // Calculate distance from point to plane
            let pointToPlane = point.position - plane.center
            let distance = simd_dot(pointToPlane, plane.normal)

            if distance > heightThreshold {
                pointsAbovePlane += 1

                // Direct proportional mapping: depth map coords -> working image coords
                let x = Int(CGFloat(point.pixelX) * scaleX)
                let y = Int(CGFloat(point.pixelY) * scaleY)

                // Fill 7x7 region for better connectivity
                for dy in -3...3 {
                    for dx in -3...3 {
                        let px = x + dx
                        let py = y + dy
                        if px >= 0 && px < workingWidth && py >= 0 && py < workingHeight {
                            mask[py * workingWidth + px] = 255
                        }
                    }
                }
            }
        }

        print("   Points above plane: \(pointsAbovePlane) / \(depthPoints.count) (\(Int(Double(pointsAbovePlane)/Double(max(depthPoints.count, 1))*100))%)")

        progressCallback?("Finding tool outlines...")

        // Morphological closing with larger kernel
        mask = morphologicalCloseMask(mask, width: workingWidth, height: workingHeight, kernelSize: 15)

        // Use Vision framework to detect contours intelligently
        let contours = detectContoursWithVision(mask: mask, width: workingWidth, height: workingHeight, progressCallback: progressCallback)

        print("   Vision contours found: \(contours.count)")

        progressCallback?("Processing geometry...")

        // Scale contours back to original size
        let scaleUp = imageSize.width / CGFloat(workingWidth)
        var scaledContours: [Contour] = []
        for contour in contours {
            let scaledPoints = contour.points.map { CGPoint(x: $0.x * scaleUp, y: $0.y * scaleUp) }
            let area = contour.area * scaleUp * scaleUp
            let bbox = CGRect(
                x: contour.boundingBox.origin.x * scaleUp,
                y: contour.boundingBox.origin.y * scaleUp,
                width: contour.boundingBox.size.width * scaleUp,
                height: contour.boundingBox.size.height * scaleUp
            )
            scaledContours.append(Contour(points: scaledPoints, area: area, boundingBox: bbox))
        }

        print("   After scaling: \(scaledContours.count)")

        // SIMPLIFIED: Only filter by minimum area, no workspace bounds filtering
        let minAreaPixels = 500.0 // Minimum area in pixels
        var filteredContours = scaledContours.filter { $0.area > minAreaPixels }

        print("   After area filter (min \(minAreaPixels)): \(filteredContours.count)")

        let processedImage = visualizeContours(contours: filteredContours, imageSize: imageSize)

        return SegmentationResult(contours: filteredContours, processedImage: processedImage)
    }

    private func detectContoursWithVision(mask: [UInt8], width: Int, height: Int, progressCallback: ((String) -> Void)?) -> [Contour] {
        // Convert mask to CGImage
        guard let providerRef = CGDataProvider(data: Data(mask) as CFData) else { return [] }

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return [] }

        // Use Vision to detect contours
        let request = VNDetectContoursRequest()
        request.revision = VNDetectContoursRequestRevision1
        request.contrastAdjustment = 1.0
        request.detectsDarkOnLight = false // White objects on black background

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let observations = request.results as? [VNContoursObservation] else {
            // Fallback to simple connected components
            return extractContoursFromMaskFast(mask, width: width, height: height, minSize: 20)
        }

        var contours: [Contour] = []

        // Convert VNContours to our Contour format
        for observation in observations {
            let topLevelContours = observation.topLevelContours

            for vnContour in topLevelContours {
                // Get normalized points
                let pointCount = vnContour.pointCount
                var points: [CGPoint] = []

                // Sample points from the contour
                let stride = max(1, pointCount / 100) // Sample up to 100 points
                for i in stride(from: 0, to: pointCount, by: stride) {
                    let normalizedPoint = vnContour.normalizedPoints[i]
                    // Convert from normalized (0-1) to pixel coordinates
                    let x = CGFloat(normalizedPoint.x) * CGFloat(width)
                    let y = (1.0 - CGFloat(normalizedPoint.y)) * CGFloat(height) // Flip Y
                    points.append(CGPoint(x: x, y: y))
                }

                if points.count >= 3 {
                    let area = calculateContourArea(points)
                    let bbox = calculateBoundingBox(points)

                    // Only include reasonably sized contours
                    if area > 100 {
                        contours.append(Contour(points: points, area: area, boundingBox: bbox))
                    }
                }
            }
        }

        return contours
    }

    private func calculateContourArea(_ points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0 }
        var area: Double = 0
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += Double(points[i].x * points[j].y)
            area -= Double(points[j].x * points[i].y)
        }
        return abs(area) / 2.0
    }

    private func calculateBoundingBox(_ points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y

        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // Helper: Morphological closing on mask
    private func morphologicalCloseMask(_ input: [UInt8], width: Int, height: Int, kernelSize: Int) -> [UInt8] {
        // Dilate
        let dilated = morphologicalOperation(input, width: width, height: height, kernelSize: kernelSize, isDilation: true)
        // Erode
        return morphologicalOperation(dilated, width: width, height: height, kernelSize: kernelSize, isDilation: false)
    }

    // FAST: Extract contours from binary mask using simplified connected components
    private func extractContoursFromMaskFast(_ mask: [UInt8], width: Int, height: Int, minSize: Int) -> [Contour] {
        var labeled = [Int](repeating: 0, count: width * height)
        var nextLabel = 1
        var contours: [Contour] = []

        // Connected components with size filtering
        for y in stride(from: 0, to: height, by: 2) {  // Skip every other row for speed
            for x in stride(from: 0, to: width, by: 2) {  // Skip every other column
                let idx = y * width + x
                if mask[idx] > 128 && labeled[idx] == 0 {
                    // Start new component with iterative flood fill
                    var componentBounds = (minX: x, maxX: x, minY: y, maxY: y)
                    let size = floodFillIterative(mask: mask, labeled: &labeled, x: x, y: y, width: width, height: height, label: nextLabel, bounds: &componentBounds)

                    if size >= minSize {
                        // Create simplified contour from bounding box
                        let bbox = CGRect(
                            x: componentBounds.minX,
                            y: componentBounds.minY,
                            width: componentBounds.maxX - componentBounds.minX,
                            height: componentBounds.maxY - componentBounds.minY
                        )

                        // Simple rectangular contour (fast)
                        let points = [
                            CGPoint(x: bbox.minX, y: bbox.minY),
                            CGPoint(x: bbox.maxX, y: bbox.minY),
                            CGPoint(x: bbox.maxX, y: bbox.maxY),
                            CGPoint(x: bbox.minX, y: bbox.maxY)
                        ]

                        contours.append(Contour(
                            points: points,
                            area: bbox.width * bbox.height,
                            boundingBox: bbox
                        ))
                    }

                    nextLabel += 1
                }
            }
        }

        return contours
    }

    // Helper: Extract contours from binary mask using connected components
    private func extractContoursFromMask(_ mask: [UInt8], width: Int, height: Int) -> [Contour] {
        var labeled = [Int](repeating: 0, count: width * height)
        var nextLabel = 1
        var contours: [Contour] = []

        // Connected components labeling (simple flood fill)
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                if mask[idx] > 128 && labeled[idx] == 0 {
                    // Start new component
                    var componentPoints: [CGPoint] = []
                    floodFill(mask: mask, labeled: &labeled, x: x, y: y, width: width, height: height, label: nextLabel, points: &componentPoints)

                    if componentPoints.count > 10 {  // Minimum points
                        let area = calculateArea(points: componentPoints)
                        let boundingBox = calculateBoundingBox(points: componentPoints)
                        contours.append(Contour(points: componentPoints, area: area, boundingBox: boundingBox))
                    }

                    nextLabel += 1
                }
            }
        }

        return contours
    }

    // FAST: Iterative flood fill that just tracks bounds
    private func floodFillIterative(mask: [UInt8], labeled: inout [Int], x: Int, y: Int, width: Int, height: Int, label: Int, bounds: inout (minX: Int, maxX: Int, minY: Int, maxY: Int)) -> Int {
        var stack: [(Int, Int)] = [(x, y)]
        var size = 0

        while !stack.isEmpty {
            let (cx, cy) = stack.removeLast()
            let idx = cy * width + cx

            guard cx >= 0, cx < width, cy >= 0, cy < height else { continue }
            guard mask[idx] > 128 && labeled[idx] == 0 else { continue }

            labeled[idx] = label
            size += 1

            // Update bounds
            bounds.minX = min(bounds.minX, cx)
            bounds.maxX = max(bounds.maxX, cx)
            bounds.minY = min(bounds.minY, cy)
            bounds.maxY = max(bounds.maxY, cy)

            // Add neighbors (4-connected)
            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
        }

        return size
    }

    // Helper: Flood fill for connected components
    private func floodFill(mask: [UInt8], labeled: inout [Int], x: Int, y: Int, width: Int, height: Int, label: Int, points: inout [CGPoint]) {
        var stack: [(Int, Int)] = [(x, y)]

        while !stack.isEmpty {
            let (cx, cy) = stack.removeLast()
            let idx = cy * width + cx

            guard cx >= 0, cx < width, cy >= 0, cy < height else { continue }
            guard mask[idx] > 128 && labeled[idx] == 0 else { continue }

            labeled[idx] = label
            points.append(CGPoint(x: cx, y: cy))

            // Add neighbors (4-connected)
            stack.append((cx + 1, cy))
            stack.append((cx - 1, cy))
            stack.append((cx, cy + 1))
            stack.append((cx, cy - 1))
        }
    }

    func segmentTools(image: UIImage, workspaceBounds: CGRect?, depthFilter: DepthFilter? = nil) -> SegmentationResult {
        guard let cgImage = image.cgImage else {
            return SegmentationResult(contours: [], processedImage: nil)
        }

        // FAST APPROACH: Use Vision framework for rectangle detection
        // This is much faster than custom image processing
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2  // Allow elongated rectangles
        request.maximumAspectRatio = 5.0
        request.minimumSize = 0.01  // Minimum 1% of image
        request.minimumConfidence = 0.3
        request.maximumObservations = 50  // Find up to 50 objects

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        var contours: [Contour] = []

        if let results = request.results {
            for observation in results {
                // Convert normalized coordinates to image coordinates
                let width = CGFloat(cgImage.width)
                let height = CGFloat(cgImage.height)

                let points = [
                    observation.topLeft,
                    observation.topRight,
                    observation.bottomRight,
                    observation.bottomLeft
                ].map { point in
                    CGPoint(
                        x: point.x * width,
                        y: (1.0 - point.y) * height  // Flip Y coordinate
                    )
                }

                let area = calculateArea(points: points)
                let boundingBox = calculateBoundingBox(points: points)

                contours.append(Contour(
                    points: points,
                    area: area,
                    boundingBox: boundingBox
                ))
            }
        }

        // Filter by workspace bounds
        if let bounds = workspaceBounds {
            contours = contours.filter { isContourInBounds($0, bounds: bounds) }
        }

        // Filter by area (remove small noise)
        let minAreaPixels = 100.0 * 100.0  // Reduced threshold
        contours = contours.filter { $0.area > minAreaPixels }

        let processedImage = visualizeContours(contours: contours, imageSize: CGSize(width: cgImage.width, height: cgImage.height))

        return SegmentationResult(contours: contours, processedImage: processedImage)
    }

    private func convertToGrayscale(_ cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    private func applyAdaptiveThreshold(_ cgImage: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)

        // Apply adaptive threshold using local statistics
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.5, forKey: kCIInputContrastKey)

        guard let output = filter?.outputImage else { return cgImage }

        guard let result = ciContext.createCGImage(output, from: output.extent) else { return cgImage }

        return result
    }

    private func detectEdges(_ cgImage: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)

        // Canny edge detection using CIEdges
        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(2.0, forKey: kCIInputIntensityKey)

        guard let output = filter?.outputImage else { return cgImage }

        guard let result = ciContext.createCGImage(output, from: output.extent) else { return cgImage }

        return result
    }

    private func morphologicalClose(_ cgImage: CGImage, kernelSize: Int) -> CGImage {
        let width = cgImage.width
        let height = cgImage.height

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return cgImage }

        // Create buffer
        var buffer = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            buffer[i] = bytes[i]
        }

        // Dilate
        buffer = morphologicalOperation(buffer, width: width, height: height, kernelSize: kernelSize, isDilation: true)

        // Erode
        buffer = morphologicalOperation(buffer, width: width, height: height, kernelSize: kernelSize, isDilation: false)

        // Create new image
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return cgImage }

        return context.makeImage() ?? cgImage
    }

    private func morphologicalOperation(_ input: [UInt8], width: Int, height: Int, kernelSize: Int, isDilation: Bool) -> [UInt8] {
        var output = input
        let half = kernelSize / 2

        for y in half..<(height - half) {
            for x in half..<(width - half) {
                var value: UInt8 = isDilation ? 0 : 255

                for ky in -half...half {
                    for kx in -half...half {
                        let px = input[(y + ky) * width + (x + kx)]
                        if isDilation {
                            value = max(value, px)
                        } else {
                            value = min(value, px)
                        }
                    }
                }

                output[y * width + x] = value
            }
        }

        return output
    }

    private func extractContours(from cgImage: CGImage, imageSize: CGSize) -> [Contour] {
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return [] }

        let width = cgImage.width
        let height = cgImage.height

        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        var contours: [Contour] = []

        // Find contours using flood fill
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixel = bytes[index]

                if pixel > 128 && !visited[y][x] {
                    let contour = traceContour(bytes: bytes, width: width, height: height, startX: x, startY: y, visited: &visited)
                    if contour.count > 10 {  // Minimum contour size
                        let points = contour.map { CGPoint(x: $0.x, y: $0.y) }
                        let area = calculateArea(points: points)
                        let bbox = calculateBoundingBox(points: points)
                        contours.append(Contour(points: points, area: area, boundingBox: bbox))
                    }
                }
            }
        }

        return contours
    }

    private func traceContour(bytes: UnsafePointer<UInt8>, width: Int, height: Int, startX: Int, startY: Int, visited: inout [[Bool]]) -> [(x: Int, y: Int)] {
        var contour: [(x: Int, y: Int)] = []
        var stack: [(Int, Int)] = [(startX, startY)]

        let directions = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

        while !stack.isEmpty {
            let (x, y) = stack.removeLast()

            guard x >= 0, x < width, y >= 0, y < height else { continue }
            guard !visited[y][x] else { continue }

            let index = y * width + x
            guard bytes[index] > 128 else { continue }

            visited[y][x] = true
            contour.append((x, y))

            for (dx, dy) in directions {
                let nx = x + dx
                let ny = y + dy
                if nx >= 0, nx < width, ny >= 0, ny < height, !visited[ny][nx] {
                    stack.append((nx, ny))
                }
            }
        }

        return contour
    }

    private func calculateArea(points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0 }

        var area: Double = 0
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += Double(points[i].x * points[j].y)
            area -= Double(points[j].x * points[i].y)
        }
        return abs(area) / 2.0
    }

    private func calculateBoundingBox(points: [CGPoint]) -> CGRect {
        guard !points.isEmpty,
              let minX = points.map({ $0.x }).min(),
              let maxX = points.map({ $0.x }).max(),
              let minY = points.map({ $0.y }).min(),
              let maxY = points.map({ $0.y }).max() else {
            return .zero
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func isContourInBounds(_ contour: Contour, bounds: CGRect) -> Bool {
        return bounds.intersects(contour.boundingBox)
    }

    private func fillInteriorHoles(_ contour: Contour) -> Contour {
        // Simplified: return original contour
        // In production, use proper hole filling algorithm
        return contour
    }

    private func visualizeContours(contours: [Contour], imageSize: CGSize) -> UIImage? {
        // Validate image size to prevent crash
        guard imageSize.width > 0 && imageSize.height > 0 else {
            print("Warning: Invalid image size (\(imageSize.width)x\(imageSize.height))")
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            let ctx = context.cgContext

            // Draw white background
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: imageSize))

            // Draw contours
            for contour in contours {
                ctx.setStrokeColor(UIColor.blue.cgColor)
                ctx.setLineWidth(2.0)

                guard let first = contour.points.first else { continue }
                ctx.move(to: first)

                for point in contour.points.dropFirst() {
                    ctx.addLine(to: point)
                }

                ctx.closePath()
                ctx.strokePath()
            }
        }
    }
}

struct DepthFilter {
    let minHeight: Float
    let maxHeight: Float
    let depthMap: [Float]
    let width: Int
    let height: Int

    func isValid(x: Int, y: Int) -> Bool {
        let index = y * width + x
        guard index >= 0, index < depthMap.count else { return false }

        let depth = depthMap[index]
        return depth >= minHeight && depth <= maxHeight
    }
}
