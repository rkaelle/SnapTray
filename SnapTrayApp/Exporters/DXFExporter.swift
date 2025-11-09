import Foundation
import CoreGraphics

class DXFExporter {
    func exportProject(_ project: Project, scale: Double) -> String {
        var dxf = generateDXFHeader()

        // Add layers
        dxf += generateLayersSection()

        // Start entities section
        dxf += "0\nSECTION\n2\nENTITIES\n"

        // Export workspace bounds
        if let bounds = project.workspaceBounds {
            dxf += drawRectangle(bounds, layer: "WORKSPACE", scale: scale)
        }

        // Export each tool pocket
        for (index, tool) in project.tools.enumerated() where tool.enabled {
            let layer = "TOOL_\(index)"

            // Original contour (for reference)
            dxf += drawPolyline(tool.contour, layer: "\(layer)_ORIGINAL", closed: true, scale: scale)

            // Simplified contour
            dxf += drawPolyline(tool.simplifiedContour, layer: "\(layer)_SIMPLIFIED", closed: true, scale: scale)

            // Offset contour (actual pocket)
            dxf += drawPolyline(tool.offsetContour, layer: "\(layer)_POCKET", closed: true, scale: scale)

            // Add finger notch if present
            if tool.hasFingerNotch, let notch = tool.fingerNotch {
                dxf += drawCircle(notch.position, radius: notch.radius, layer: "\(layer)_NOTCH", scale: scale)
            }

            // Add text label
            if !tool.label.isEmpty {
                let centroid = calculateCentroid(tool.offsetContour)
                dxf += drawText(tool.label, at: centroid, layer: "\(layer)_LABEL", height: 5.0, scale: scale)
            }

            // Add depth annotation
            let bbox = tool.boundingBox
            let annotationPos = CGPoint(x: bbox.maxX + 10, y: bbox.midY)
            let depthText = String(format: "D: %.1fmm", tool.effectiveDepth)
            dxf += drawText(depthText, at: annotationPos, layer: "\(layer)_DEPTH", height: 3.0, scale: scale)
        }

        // Add tray outline
        if let bounds = project.workspaceBounds {
            let margin = project.traySettings.edgeMargin
            let trayBounds = CGRect(
                x: bounds.minX - margin,
                y: bounds.minY - margin,
                width: bounds.width + 2 * margin,
                height: bounds.height + 2 * margin
            )
            dxf += drawRectangle(trayBounds, layer: "TRAY_OUTLINE", scale: scale)
        }

        // End entities section
        dxf += "0\nENDSEC\n"

        // Add footer
        dxf += "0\nEOF\n"

        return dxf
    }

    private func generateDXFHeader() -> String {
        var header = "0\nSECTION\n2\nHEADER\n"

        // AutoCAD version
        header += "9\n$ACADVER\n1\nAC1021\n"

        // Units (millimeters)
        header += "9\n$INSUNITS\n70\n4\n"

        // Measurement (metric)
        header += "9\n$MEASUREMENT\n70\n1\n"

        header += "0\nENDSEC\n"

        return header
    }

    private func generateLayersSection() -> String {
        var section = "0\nSECTION\n2\nTABLES\n"
        section += "0\nTABLE\n2\nLAYER\n"

        let layers = [
            ("WORKSPACE", 7),      // White
            ("TRAY_OUTLINE", 1),   // Red
            ("TOOL_ORIGINAL", 8),  // Gray
            ("TOOL_SIMPLIFIED", 6),// Magenta
            ("TOOL_POCKET", 2),    // Yellow
            ("TOOL_NOTCH", 3),     // Green
            ("TOOL_LABEL", 4),     // Cyan
            ("TOOL_DEPTH", 5)      // Blue
        ]

        for (name, color) in layers {
            section += "0\nLAYER\n"
            section += "2\n\(name)\n"
            section += "70\n0\n"
            section += "62\n\(color)\n"
            section += "6\nCONTINUOUS\n"
        }

        section += "0\nENDTAB\n"
        section += "0\nENDSEC\n"

        return section
    }

    private func drawPolyline(_ points: [CGPoint], layer: String, closed: Bool, scale: Double) -> String {
        guard !points.isEmpty else { return "" }

        var dxf = "0\nLWPOLYLINE\n"
        dxf += "8\n\(layer)\n"
        dxf += "90\n\(points.count)\n"
        dxf += "70\n\(closed ? 1 : 0)\n"

        for point in points {
            let scaled = scalePoint(point, scale: scale)
            dxf += "10\n\(scaled.x)\n"
            dxf += "20\n\(scaled.y)\n"
        }

        return dxf
    }

    private func drawRectangle(_ rect: CGRect, layer: String, scale: Double) -> String {
        let points = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]

        return drawPolyline(points, layer: layer, closed: true, scale: scale)
    }

    private func drawCircle(_ center: CGPoint, radius: Double, layer: String, scale: Double) -> String {
        let scaled = scalePoint(center, scale: scale)
        let scaledRadius = radius * scale

        var dxf = "0\nCIRCLE\n"
        dxf += "8\n\(layer)\n"
        dxf += "10\n\(scaled.x)\n"
        dxf += "20\n\(scaled.y)\n"
        dxf += "40\n\(scaledRadius)\n"

        return dxf
    }

    private func drawText(_ text: String, at position: CGPoint, layer: String, height: Double, scale: Double) -> String {
        let scaled = scalePoint(position, scale: scale)

        var dxf = "0\nTEXT\n"
        dxf += "8\n\(layer)\n"
        dxf += "10\n\(scaled.x)\n"
        dxf += "20\n\(scaled.y)\n"
        dxf += "40\n\(height * scale)\n"
        dxf += "1\n\(text)\n"

        return dxf
    }

    private func scalePoint(_ point: CGPoint, scale: Double) -> CGPoint {
        return CGPoint(x: point.x * scale, y: point.y * scale)
    }

    private func calculateCentroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }

        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    func saveToFile(_ dxf: String, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)

        do {
            try dxf.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving DXF file: \(error)")
            return nil
        }
    }
}
