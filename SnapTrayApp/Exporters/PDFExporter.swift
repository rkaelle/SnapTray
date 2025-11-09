import UIKit
import PDFKit

class PDFExporter {
    func generatePrintablePDF(project: Project, capturedImage: UIImage?) -> Data? {
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792)  // US Letter
        let pdfMetadata = [
            kCGPDFContextTitle: "SnapTray Scan Results - \(project.name)",
            kCGPDFContextAuthor: "SnapTray",
            kCGPDFContextCreator: "SnapTray App"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]

        let renderer = UIGraphicsPDFRenderer(bounds: pageSize, format: format)

        let data = renderer.pdfData { context in
            // Page 1: Overview with image and summary
            context.beginPage()
            drawOverviewPage(context: context.cgContext, pageSize: pageSize, project: project, image: capturedImage)

            // Page 2: Detailed measurements for each tool
            context.beginPage()
            drawMeasurementsPage(context: context.cgContext, pageSize: pageSize, project: project)

            // Page 3: Scale calibration template
            context.beginPage()
            drawScaleCalibrationPage(context: context.cgContext, pageSize: pageSize, project: project)
        }

        return data
    }

    private func drawOverviewPage(context: CGContext, pageSize: CGRect, project: Project, image: UIImage?) {
        let margin: CGFloat = 50

        // Title
        var yPos: CGFloat = margin
        context.setFillColor(UIColor.black.cgColor)

        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let title = "SnapTray Scan Results"
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttrs)

        yPos += titleSize.height + 10

        // Project name
        let nameFont = UIFont.systemFont(ofSize: 18)
        let nameText = "Project: \(project.name)"
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.darkGray]
        nameText.draw(at: CGPoint(x: margin, y: yPos), withAttributes: nameAttrs)

        yPos += 30

        // Date
        let dateFont = UIFont.systemFont(ofSize: 12)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateText = "Generated: \(dateFormatter.string(from: Date()))"
        let dateAttrs: [NSAttributedString.Key: Any] = [.font: dateFont, .foregroundColor: UIColor.gray]
        dateText.draw(at: CGPoint(x: margin, y: yPos), withAttributes: dateAttrs)

        yPos += 40

        // Captured image
        if let image = image {
            let imageHeight: CGFloat = 300
            let imageWidth = pageSize.width - 2 * margin
            let imageRect = CGRect(x: margin, y: yPos, width: imageWidth, height: imageHeight)

            context.saveGState()
            context.addRect(imageRect)
            context.clip()
            image.draw(in: imageRect)
            context.restoreGState()

            // Border around image
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineWidth(1)
            context.stroke(imageRect)

            yPos += imageHeight + 30
        }

        // Summary section
        let summaryFont = UIFont.boldSystemFont(ofSize: 16)
        let summaryTitle = "Scan Summary"
        let summaryAttrs: [NSAttributedString.Key: Any] = [.font: summaryFont, .foregroundColor: UIColor.black]
        summaryTitle.draw(at: CGPoint(x: margin, y: yPos), withAttributes: summaryAttrs)

        yPos += 25

        let infoFont = UIFont.systemFont(ofSize: 12)
        let infoAttrs: [NSAttributedString.Key: Any] = [.font: infoFont, .foregroundColor: UIColor.black]

        let enabledTools = project.tools.filter { $0.enabled }

        let info = [
            "Number of tools detected: \(enabledTools.count)",
            "Material: \(project.traySettings.material.displayName)",
            "Tray thickness: \(String(format: "%.1f mm", project.traySettings.trayThickness))",
            "Edge margin: \(String(format: "%.1f mm", project.traySettings.edgeMargin))",
            "XY interference: \(String(format: "%.2f mm", project.traySettings.xyInterference))",
            ""
        ]

        for line in info {
            line.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: infoAttrs)
            yPos += 18
        }

        // Scale information
        if let scale = project.pixelToMMScale {
            let scaleText = String(format: "Scale: %.3f mm/pixel", scale)
            scaleText.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: infoAttrs)
            yPos += 18
        }

        // Workspace dimensions
        if let bounds = project.workspaceBounds, let scale = project.pixelToMMScale {
            let widthMM = bounds.width * scale
            let heightMM = bounds.height * scale
            let dimText = String(format: "Workspace: %.1f × %.1f mm", widthMM, heightMM)
            dimText.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: infoAttrs)
        }
    }

    private func drawMeasurementsPage(context: CGContext, pageSize: CGRect, project: Project) {
        let margin: CGFloat = 50
        var yPos: CGFloat = margin

        // Title
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let title = "Tool Measurements"
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
        title.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttrs)

        yPos += 35

        // Table headers
        let headerFont = UIFont.boldSystemFont(ofSize: 11)
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.black]

        let col1X: CGFloat = margin
        let col2X: CGFloat = margin + 50
        let col3X: CGFloat = margin + 250
        let col4X: CGFloat = margin + 350
        let col5X: CGFloat = margin + 450

        "#".draw(at: CGPoint(x: col1X, y: yPos), withAttributes: headerAttrs)
        "Label".draw(at: CGPoint(x: col2X, y: yPos), withAttributes: headerAttrs)
        "Area (mm²)".draw(at: CGPoint(x: col3X, y: yPos), withAttributes: headerAttrs)
        "Depth (mm)".draw(at: CGPoint(x: col4X, y: yPos), withAttributes: headerAttrs)
        "Notch".draw(at: CGPoint(x: col5X, y: yPos), withAttributes: headerAttrs)

        yPos += 20

        // Draw header underline
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: yPos))
        context.addLine(to: CGPoint(x: pageSize.width - margin, y: yPos))
        context.strokePath()

        yPos += 10

        // Tool rows
        let cellFont = UIFont.systemFont(ofSize: 10)
        let cellAttrs: [NSAttributedString.Key: Any] = [.font: cellFont, .foregroundColor: UIColor.black]

        let enabledTools = project.tools.filter { $0.enabled }
        let scale = project.pixelToMMScale ?? 1.0

        for (index, tool) in enabledTools.enumerated() {
            if yPos > pageSize.height - margin - 20 {
                break  // Page full
            }

            let num = "\(index + 1)"
            let label = tool.label.isEmpty ? "—" : tool.label
            let areaMM = tool.area * scale * scale
            let areaText = String(format: "%.1f", areaMM)
            let depthText = String(format: "%.1f", tool.effectiveDepth)
            let notchText = tool.hasFingerNotch ? "Yes" : "No"

            num.draw(at: CGPoint(x: col1X, y: yPos), withAttributes: cellAttrs)
            label.draw(at: CGPoint(x: col2X, y: yPos), withAttributes: cellAttrs)
            areaText.draw(at: CGPoint(x: col3X, y: yPos), withAttributes: cellAttrs)
            depthText.draw(at: CGPoint(x: col4X, y: yPos), withAttributes: cellAttrs)
            notchText.draw(at: CGPoint(x: col5X, y: yPos), withAttributes: cellAttrs)

            yPos += 18

            // Dimensions
            let bbox = tool.boundingBox
            let widthMM = bbox.width * scale
            let heightMM = bbox.height * scale
            let dimText = String(format: "  Dimensions: %.1f × %.1f mm", widthMM, heightMM)
            let dimAttrs: [NSAttributedString.Key: Any] = [.font: cellFont, .foregroundColor: UIColor.darkGray]
            dimText.draw(at: CGPoint(x: col2X, y: yPos), withAttributes: dimAttrs)

            yPos += 20
        }

        // Footer notes
        yPos = pageSize.height - margin - 60

        let noteFont = UIFont.italicSystemFont(ofSize: 9)
        let noteAttrs: [NSAttributedString.Key: Any] = [.font: noteFont, .foregroundColor: UIColor.gray]

        let notes = [
            "Note: All measurements are in millimeters unless otherwise specified.",
            "Area includes the tool outline before offset/interference adjustments.",
            "Depth is measured from LiDAR data and represents the maximum tool thickness."
        ]

        for note in notes {
            note.draw(at: CGPoint(x: margin, y: yPos), withAttributes: noteAttrs)
            yPos += 12
        }
    }

    private func drawScaleCalibrationPage(context: CGContext, pageSize: CGRect, project: Project) {
        let margin: CGFloat = 50
        var yPos: CGFloat = margin

        // Title
        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let title = "Scale Calibration Template"
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
        title.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttrs)

        yPos += 35

        // Instructions
        let instrFont = UIFont.systemFont(ofSize: 11)
        let instrAttrs: [NSAttributedString.Key: Any] = [.font: instrFont, .foregroundColor: UIColor.black]

        let instructions = [
            "Print this page at 100% scale (no scaling/fit-to-page).",
            "Use this template to verify your scan accuracy:",
            "  1. Place a ruler next to the scale bars below",
            "  2. Verify that 100mm on the template matches 100mm on your ruler",
            "  3. If measurements don't match, adjust your printer scaling settings",
            ""
        ]

        for line in instructions {
            line.draw(at: CGPoint(x: margin, y: yPos), withAttributes: instrAttrs)
            yPos += 16
        }

        yPos += 20

        // Draw scale bars
        let mmPerPoint: CGFloat = 72.0 / 25.4  // Points per mm (72 DPI / 25.4 mm per inch)

        // 100mm scale bar
        drawScaleBar(
            context: context,
            origin: CGPoint(x: margin, y: yPos),
            lengthMM: 100,
            mmPerPoint: mmPerPoint,
            label: "100 mm"
        )

        yPos += 60

        // 50mm scale bar
        drawScaleBar(
            context: context,
            origin: CGPoint(x: margin, y: yPos),
            lengthMM: 50,
            mmPerPoint: mmPerPoint,
            label: "50 mm"
        )

        yPos += 60

        // 25mm scale bar
        drawScaleBar(
            context: context,
            origin: CGPoint(x: margin, y: yPos),
            lengthMM: 25,
            mmPerPoint: mmPerPoint,
            label: "25 mm"
        )

        yPos += 80

        // Scan info
        if let scale = project.pixelToMMScale {
            let scaleInfo = String(format: "Your scan scale: %.4f mm/pixel", scale)
            let scaleFont = UIFont.systemFont(ofSize: 10)
            let scaleAttrs: [NSAttributedString.Key: Any] = [.font: scaleFont, .foregroundColor: UIColor.darkGray]
            scaleInfo.draw(at: CGPoint(x: margin, y: yPos), withAttributes: scaleAttrs)
            yPos += 15

            if let bounds = project.workspaceBounds {
                let widthMM = bounds.width * scale
                let heightMM = bounds.height * scale
                let workspaceInfo = String(format: "Workspace size: %.1f × %.1f mm", widthMM, heightMM)
                workspaceInfo.draw(at: CGPoint(x: margin, y: yPos), withAttributes: scaleAttrs)
            }
        }

        // Draw grid for reference
        yPos += 40
        drawCalibrationGrid(context: context, origin: CGPoint(x: margin, y: yPos), mmPerPoint: mmPerPoint)
    }

    private func drawScaleBar(context: CGContext, origin: CGPoint, lengthMM: Double, mmPerPoint: CGFloat, label: String) {
        let lengthPoints = CGFloat(lengthMM) * mmPerPoint

        // Main bar
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2)
        context.move(to: origin)
        context.addLine(to: CGPoint(x: origin.x + lengthPoints, y: origin.y))
        context.strokePath()

        // Tick marks every 10mm
        context.setLineWidth(1)
        let tickHeight: CGFloat = 10

        for i in 0...Int(lengthMM / 10) {
            let x = origin.x + CGFloat(i * 10) * mmPerPoint
            context.move(to: CGPoint(x: x, y: origin.y - tickHeight / 2))
            context.addLine(to: CGPoint(x: x, y: origin.y + tickHeight / 2))
        }
        context.strokePath()

        // Label
        let font = UIFont.boldSystemFont(ofSize: 10)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        label.draw(at: CGPoint(x: origin.x + lengthPoints + 10, y: origin.y - 7), withAttributes: attrs)
    }

    private func drawCalibrationGrid(context: CGContext, origin: CGPoint, mmPerPoint: CGFloat) {
        let gridSize: CGFloat = 50  // 50mm grid
        let rows = 3
        let cols = 5

        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)

        let cellSize = gridSize * mmPerPoint

        // Draw grid
        for row in 0...rows {
            let y = origin.y + CGFloat(row) * cellSize
            context.move(to: CGPoint(x: origin.x, y: y))
            context.addLine(to: CGPoint(x: origin.x + CGFloat(cols) * cellSize, y: y))
        }

        for col in 0...cols {
            let x = origin.x + CGFloat(col) * cellSize
            context.move(to: CGPoint(x: x, y: origin.y))
            context.addLine(to: CGPoint(x: x, y: origin.y + CGFloat(rows) * cellSize))
        }

        context.strokePath()

        // Label
        let font = UIFont.systemFont(ofSize: 9)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.gray]
        "50mm grid".draw(at: CGPoint(x: origin.x, y: origin.y + CGFloat(rows) * cellSize + 5), withAttributes: attrs)
    }

    func saveToFile(_ data: Data, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving PDF file: \(error)")
            return nil
        }
    }
}
