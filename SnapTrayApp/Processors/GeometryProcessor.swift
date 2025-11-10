import Foundation
import CoreGraphics

class GeometryProcessor {
    // Simplify contour using Douglas-Peucker algorithm
    func simplifyContour(_ points: [CGPoint], tolerance: Double = 2.0) -> [CGPoint] {
        guard points.count > 2 else { return points }
        return douglasPeucker(points: points, epsilon: tolerance)
    }

    // Douglas-Peucker implementation
    private func douglasPeucker(points: [CGPoint], epsilon: Double) -> [CGPoint] {
        guard points.count > 2,
              let start = points.first,
              let end = points.last else {
            return points
        }

        var maxDistance = 0.0
        var maxIndex = 0

        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: start, lineEnd: end)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        if maxDistance > epsilon {
            let left = douglasPeucker(points: Array(points[0...maxIndex]), epsilon: epsilon)
            let right = douglasPeucker(points: Array(points[maxIndex..<points.count]), epsilon: epsilon)

            return left.dropLast() + right
        } else {
            return [start, end]
        }
    }

    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y

        let numerator = abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        let denominator = sqrt(dx * dx + dy * dy)

        return Double(numerator / denominator)
    }

    // Offset contour inward/outward
    func offsetContour(_ points: [CGPoint], offset: Double) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var offsetPoints: [CGPoint] = []

        for i in 0..<points.count {
            let prev = points[(i - 1 + points.count) % points.count]
            let curr = points[i]
            let next = points[(i + 1) % points.count]

            // Calculate normals
            let normal1 = calculateNormal(from: prev, to: curr)
            let normal2 = calculateNormal(from: curr, to: next)

            // Average normal
            let avgNormal = CGPoint(
                x: (normal1.x + normal2.x) / 2,
                y: (normal1.y + normal2.y) / 2
            )

            // Normalize
            let length = sqrt(avgNormal.x * avgNormal.x + avgNormal.y * avgNormal.y)
            let normalized = CGPoint(
                x: avgNormal.x / length,
                y: avgNormal.y / length
            )

            // Apply offset
            let offsetPoint = CGPoint(
                x: curr.x + normalized.x * offset,
                y: curr.y + normalized.y * offset
            )

            offsetPoints.append(offsetPoint)
        }

        return offsetPoints
    }

    private func calculateNormal(from p1: CGPoint, to p2: CGPoint) -> CGPoint {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y

        // Perpendicular vector (rotate 90 degrees)
        return CGPoint(x: -dy, y: dx)
    }

    // Apply fillet to corners
    func applyFillets(_ points: [CGPoint], radius: Double) -> [CGPoint] {
        guard points.count > 2, radius > 0 else { return points }

        var filleted: [CGPoint] = []

        for i in 0..<points.count {
            let prev = points[(i - 1 + points.count) % points.count]
            let curr = points[i]
            let next = points[(i + 1) % points.count]

            // Calculate distances
            let dist1 = distance(prev, curr)
            let dist2 = distance(curr, next)

            // Limit fillet radius to half the minimum edge length
            let maxRadius = min(dist1, dist2) / 2
            let actualRadius = min(radius, maxRadius)

            if actualRadius < 0.1 {
                filleted.append(curr)
                continue
            }

            // Calculate fillet points
            let dir1 = normalize(CGPoint(x: prev.x - curr.x, y: prev.y - curr.y))
            let dir2 = normalize(CGPoint(x: next.x - curr.x, y: next.y - curr.y))

            let p1 = CGPoint(
                x: curr.x + dir1.x * actualRadius,
                y: curr.y + dir1.y * actualRadius
            )

            let p2 = CGPoint(
                x: curr.x + dir2.x * actualRadius,
                y: curr.y + dir2.y * actualRadius
            )

            // Add arc points
            let arcPoints = createArc(start: p1, end: p2, center: curr, segments: 5)
            filleted.append(contentsOf: arcPoints)
        }

        return filleted
    }

    private func createArc(start: CGPoint, end: CGPoint, center: CGPoint, segments: Int) -> [CGPoint] {
        var points: [CGPoint] = []

        let startAngle = atan2(start.y - center.y, start.x - center.x)
        let endAngle = atan2(end.y - center.y, end.x - center.x)

        var angleDiff = endAngle - startAngle
        if angleDiff > .pi {
            angleDiff -= 2 * .pi
        } else if angleDiff < -.pi {
            angleDiff += 2 * .pi
        }

        let radius = distance(start, center)

        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let angle = startAngle + angleDiff * t

            let point = CGPoint(
                x: center.x + CGFloat(radius * Darwin.cos(angle)),
                y: center.y + CGFloat(radius * Darwin.sin(angle))
            )
            points.append(point)
        }

        return points
    }

    // Add finger notch to contour
    func addFingerNotch(to points: [CGPoint], notch: FingerNotch) -> [CGPoint] {
        guard points.count > notch.edgeIndex + 1 else { return points }

        let p1 = points[notch.edgeIndex]
        let p2 = points[(notch.edgeIndex + 1) % points.count]

        // Calculate notch position along edge
        let notchCenter = CGPoint(
            x: p1.x + (p2.x - p1.x) * notch.normalizedPosition,
            y: p1.y + (p2.y - p1.y) * notch.normalizedPosition
        )

        // Calculate perpendicular direction
        let edgeDir = normalize(CGPoint(x: p2.x - p1.x, y: p2.y - p1.y))
        let perpDir = CGPoint(x: -edgeDir.y, y: edgeDir.x)

        // Create semicircular notch
        var notchPoints: [CGPoint] = []
        let segments = 12

        for i in 0...segments {
            let angle = .pi * Double(i) / Double(segments)
            let offset = CGPoint(
                x: notchCenter.x + perpDir.x * notch.radius * Darwin.sin(angle) + edgeDir.x * notch.radius * Darwin.cos(angle),
                y: notchCenter.y + perpDir.y * notch.radius * Darwin.sin(angle) + edgeDir.y * notch.radius * Darwin.cos(angle)
            )
            notchPoints.append(offset)
        }

        // Insert notch into contour
        var result = Array(points[0...notch.edgeIndex])
        result.append(contentsOf: notchPoints)
        result.append(contentsOf: points[(notch.edgeIndex + 1)..<points.count])

        return result
    }

    // Find longest edge in contour
    func findLongestEdge(in points: [CGPoint]) -> Int {
        guard points.count > 1 else { return 0 }

        var maxLength = 0.0
        var maxIndex = 0

        for i in 0..<points.count {
            let j = (i + 1) % points.count
            let length = distance(points[i], points[j])

            if length > maxLength {
                maxLength = length
                maxIndex = i
            }
        }

        return maxIndex
    }

    // Calculate optimal notch radius based on tool size
    func calculateNotchRadius(for boundingBox: CGRect) -> Double {
        let minDimension = min(boundingBox.width, boundingBox.height)

        if minDimension < 30 {
            return 6.0  // Small tools
        } else if minDimension < 60 {
            return 8.0  // Medium tools
        } else {
            return 10.0  // Large tools
        }
    }

    // Helper functions
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    private func normalize(_ point: CGPoint) -> CGPoint {
        let length = sqrt(point.x * point.x + point.y * point.y)
        guard length > 0 else { return point }
        return CGPoint(x: point.x / length, y: point.y / length)
    }

    // Convert contour to DXF polyline format
    func contourToDXFPolyline(_ points: [CGPoint], layer: String = "0", closed: Bool = true) -> String {
        var dxf = "0\nLWPOLYLINE\n"
        dxf += "8\n\(layer)\n"
        dxf += "90\n\(points.count)\n"
        dxf += "70\n\(closed ? 1 : 0)\n"

        for point in points {
            dxf += "10\n\(point.x)\n"
            dxf += "20\n\(point.y)\n"
        }

        return dxf
    }

    // Scale points by factor
    func scalePoints(_ points: [CGPoint], scale: Double) -> [CGPoint] {
        return points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
    }

    // Translate points by offset
    func translatePoints(_ points: [CGPoint], offset: CGPoint) -> [CGPoint] {
        return points.map { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) }
    }

    // Calculate centroid
    func calculateCentroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }

        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
}
