import UIKit
import Vision
import CoreImage
import Accelerate

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

    func segmentTools(image: UIImage, workspaceBounds: CGRect?, depthFilter: DepthFilter? = nil) -> SegmentationResult {
        guard let cgImage = image.cgImage else {
            return SegmentationResult(contours: [], processedImage: nil)
        }

        // Step 1: Convert to grayscale
        guard let grayImage = convertToGrayscale(cgImage) else {
            return SegmentationResult(contours: [], processedImage: nil)
        }

        // Step 2: Apply threshold
        let thresholded = applyAdaptiveThreshold(grayImage)

        // Step 3: Edge detection
        let edges = detectEdges(thresholded)

        // Step 4: Morphological operations (close gaps)
        let closed = morphologicalClose(edges, kernelSize: 5)

        // Step 5: Extract contours
        var contours = extractContours(from: closed, imageSize: CGSize(width: cgImage.width, height: cgImage.height))

        // Step 6: Filter by workspace bounds
        if let bounds = workspaceBounds {
            contours = contours.filter { isContourInBounds($0, bounds: bounds) }
        }

        // Step 7: Filter by area (remove small noise)
        let minAreaPixels = 200.0 * 200.0  // ~200mm² at 1px/mm
        contours = contours.filter { $0.area > minAreaPixels }

        // Step 8: Fill interior holes
        contours = contours.map { fillInteriorHoles($0) }

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

        let context = CIContext()
        guard let result = context.createCGImage(output, from: output.extent) else { return cgImage }

        return result
    }

    private func detectEdges(_ cgImage: CGImage) -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)

        // Canny edge detection using CIEdges
        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(2.0, forKey: kCIInputIntensityKey)

        guard let output = filter?.outputImage else { return cgImage }

        let context = CIContext()
        guard let result = context.createCGImage(output, from: output.extent) else { return cgImage }

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
