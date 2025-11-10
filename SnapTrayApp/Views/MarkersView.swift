import SwiftUI
import UIKit

struct MarkersView: View {
    @State private var showingSaveConfirmation = false
    @State private var savedMarkerID: Int?
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Fiducial Markers")
                            .font(.title.bold())

                        Text("Save these markers to your device, then print them on standard paper")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)

                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Setup Instructions")
                            .font(.headline)

                        InstructionRow(number: 1, text: "Tap each marker below to save to Photos")
                        InstructionRow(number: 2, text: "Print all 4 markers on white paper")
                        InstructionRow(number: 3, text: "Cut out markers leaving white border")
                        InstructionRow(number: 4, text: "Place markers at corners of your workspace")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Save All Button
                    Button(action: saveAllMarkers) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("Save All 4 Markers")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Marker Grid
                    VStack(spacing: 20) {
                        ForEach(0..<4) { id in
                            MarkerCard(markerID: id, onSave: {
                                saveMarker(id: id)
                            })
                        }
                    }
                    .padding(.horizontal)

                    // Printing Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Printing Tips")
                            .font(.headline)

                        TipRow(icon: "printer.fill", text: "Print at 100% scale (no scaling)")
                        TipRow(icon: "sun.max.fill", text: "Use high-quality/photo print mode")
                        TipRow(icon: "rectangle.fill", text: "Ensure paper is flat, no curling")
                        TipRow(icon: "scissors", text: "Keep the white border around markers")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Fiducial Markers")
            .alert("Marker Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                if let id = savedMarkerID {
                    Text("Marker #\(id + 1) saved to Photos. You can now print it.")
                } else {
                    Text("All 4 markers saved to Photos. You can now print them.")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveMarker(id: Int) {
        let generator = ArucoMarkerGenerator()
        guard let markerImage = generator.generateMarker(id: id, size: 800) else {
            errorMessage = "Failed to generate marker image"
            showingError = true
            return
        }

        UIImageWriteToSavedPhotosAlbum(markerImage, nil, nil, nil)
        savedMarkerID = id
        showingSaveConfirmation = true
    }

    private func saveAllMarkers() {
        let generator = ArucoMarkerGenerator()
        for id in 0..<4 {
            if let markerImage = generator.generateMarker(id: id, size: 800) {
                UIImageWriteToSavedPhotosAlbum(markerImage, nil, nil, nil)
            }
        }
        savedMarkerID = nil
        showingSaveConfirmation = true
    }
}

struct MarkerCard: View {
    let markerID: Int
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Marker #\(markerID + 1)")
                    .font(.headline)
                Spacer()
                Text("ID: \(markerID)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Marker Preview
            if let markerImage = ArucoMarkerGenerator().generateMarker(id: markerID, size: 400) {
                Image(uiImage: markerImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .background(Color.white)
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay(
                        Text("Failed to generate")
                            .foregroundColor(.secondary)
                    )
            }

            Button(action: onSave) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save to Photos")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 20, alignment: .leading)

            Text(text)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// ArUco Marker Generator
class ArucoMarkerGenerator {
    // ArUco 4x4 dictionary patterns (simplified - using first 10 IDs from ArUco 4x4_50)
    private let arucoPatterns: [[Int]] = [
        // ID 0
        [0, 1, 1, 0,
         1, 0, 1, 1,
         0, 1, 0, 0,
         0, 1, 1, 1],

        // ID 1
        [0, 1, 1, 0,
         1, 1, 0, 0,
         1, 0, 0, 1,
         1, 0, 0, 1],

        // ID 2
        [0, 1, 0, 1,
         1, 1, 0, 1,
         1, 1, 0, 0,
         0, 0, 1, 0],

        // ID 3
        [0, 1, 0, 1,
         0, 1, 1, 1,
         0, 1, 1, 0,
         1, 1, 0, 0]
    ]

    func generateMarker(id: Int, size: Int) -> UIImage? {
        guard id >= 0 && id < arucoPatterns.count else { return nil }

        let pattern = arucoPatterns[id]

        // Total size including border (1 cell border all around)
        let cellsPerSide = 6  // 4x4 pattern + 1 cell border on each side
        let cellSize = size / cellsPerSide
        let totalSize = cellSize * cellsPerSide

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))

        return renderer.image { ctx in
            let context = ctx.cgContext

            // Fill with white background
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: totalSize, height: totalSize))

            // Draw black border (1 cell thick)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: totalSize, height: cellSize)) // Top
            context.fill(CGRect(x: 0, y: totalSize - cellSize, width: totalSize, height: cellSize)) // Bottom
            context.fill(CGRect(x: 0, y: 0, width: cellSize, height: totalSize)) // Left
            context.fill(CGRect(x: totalSize - cellSize, y: 0, width: cellSize, height: totalSize)) // Right

            // Draw the 4x4 pattern (with 1 cell offset for border)
            for row in 0..<4 {
                for col in 0..<4 {
                    let patternIndex = row * 4 + col
                    let bit = pattern[patternIndex]

                    if bit == 1 {
                        let x = (col + 1) * cellSize
                        let y = (row + 1) * cellSize
                        context.fill(CGRect(x: x, y: y, width: cellSize, height: cellSize))
                    }
                }
            }
        }
    }
}
