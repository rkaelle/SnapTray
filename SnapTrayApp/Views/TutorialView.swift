import SwiftUI

struct TutorialView: View {
    @State private var selectedStep = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Step indicator
                StepIndicator(currentStep: selectedStep, totalSteps: tutorialSteps.count)
                    .padding()

                // Content
                TabView(selection: $selectedStep) {
                    ForEach(Array(tutorialSteps.enumerated()), id: \.element.id) { index, step in
                        TutorialStepView(step: step, stepNumber: index + 1, totalSteps: tutorialSteps.count)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation
                HStack(spacing: 20) {
                    if selectedStep > 0 {
                        Button(action: { selectedStep -= 1 }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                        }
                    }

                    if selectedStep < tutorialSteps.count - 1 {
                        Button(action: { selectedStep += 1 }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    } else {
                        Button(action: { selectedStep = 0 }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Restart")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Tutorial")
        }
    }
}

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

struct TutorialStepView: View {
    let step: TutorialStep
    let stepNumber: Int
    let totalSteps: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Step number
                HStack {
                    Text("Step \(stepNumber) of \(totalSteps)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Icon
                Image(systemName: step.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()

                // Title
                Text(step.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                // Description
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // Instructions
                if !step.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(step.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                    .frame(width: 24, alignment: .leading)

                                Text(instruction)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Tips
                if !step.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tips", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundColor(.orange)

                        ForEach(step.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)

                                Text(tip)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Warnings
                if !step.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Important", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)

                        ForEach(step.warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)

                                Text(warning)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct TutorialStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let instructions: [String]
    let tips: [String]
    let warnings: [String]
}

let tutorialSteps: [TutorialStep] = [
    TutorialStep(
        title: "Welcome to SnapTray",
        description: "SnapTray uses your iPhone's LiDAR sensor to scan tools and automatically generate custom 3D-printable trays. Let's get you started!",
        icon: "hand.wave.fill",
        instructions: [
            "This tutorial will guide you through the entire process",
            "You can return to any step at any time",
            "Make sure you have an iPhone with LiDAR (iPhone 12 Pro or later)"
        ],
        tips: [
            "Take your time with each step",
            "The quality of your scan depends on proper setup"
        ],
        warnings: []
    ),

    TutorialStep(
        title: "Prepare Fiducial Markers",
        description: "Fiducial markers help SnapTray establish accurate scale and boundaries for your scan.",
        icon: "square.grid.2x2.fill",
        instructions: [
            "Print 4 ArUco markers (50mm × 50mm each) from the docs folder",
            "OR use 4 US quarters (24.26mm diameter) as simple markers",
            "For best results: tape ArUco markers to quarters for dual detection",
            "Keep markers clean and flat"
        ],
        tips: [
            "Print markers at 100% scale (no fit-to-page)",
            "Use white paper for best contrast",
            "Laminate markers for durability"
        ],
        warnings: [
            "Do not resize markers when printing",
            "Wrinkled markers will not be detected properly"
        ]
    ),

    TutorialStep(
        title: "Set Up Background",
        description: "A proper background ensures clean tool detection and accurate results.",
        icon: "rectangle.fill",
        instructions: [
            "Use a black matte foam board (18\" × 24\" or larger)",
            "Place on a flat, stable surface",
            "Ensure background is smooth (no wrinkles)",
            "Tape down corners if needed"
        ],
        tips: [
            "Black foam board works best for metal tools",
            "Matte finish prevents LiDAR reflections",
            "You can reuse the same background for all scans"
        ],
        warnings: [
            "Avoid glossy or reflective surfaces",
            "Don't use white backgrounds (poor contrast)"
        ]
    ),

    TutorialStep(
        title: "Arrange Tools & Markers",
        description: "Proper tool arrangement is critical for accurate scanning.",
        icon: "wrench.and.screwdriver.fill",
        instructions: [
            "Place 4 fiducial markers at the corners of your desired tray area",
            "Markers should form a rough rectangle (doesn't need to be perfect)",
            "Space markers 150-300mm apart",
            "Lay tools FLAT on the background inside the marker boundary",
            "Leave 10-20mm spacing between tools",
            "Ensure no tools overlap"
        ],
        tips: [
            "Group similar tools together",
            "Orient tools for easy removal from tray",
            "Clean tools before scanning for better detection"
        ],
        warnings: [
            "Tools must lie completely flat (not standing up)",
            "Very small tools (<10mm) may not be detected",
            "Shiny tools may need light adjustment"
        ]
    ),

    TutorialStep(
        title: "Set Up Lighting",
        description: "Good lighting ensures accurate scanning and tool detection.",
        icon: "lightbulb.fill",
        instructions: [
            "Use diffuse overhead lighting (LED panel or ceiling light)",
            "Avoid direct sunlight or harsh shadows",
            "Ensure even illumination across entire workspace",
            "Test by taking a photo - should see all tools clearly"
        ],
        tips: [
            "Cloudy day near window = perfect natural light",
            "Bounce light off ceiling for diffusion",
            "Multiple soft lights better than one harsh light"
        ],
        warnings: [
            "Avoid harsh shadows (hides tool edges)",
            "Don't use flash or direct spotlights"
        ]
    ),

    TutorialStep(
        title: "Scan with LiDAR",
        description: "Time to capture your tool layout!",
        icon: "camera.fill",
        instructions: [
            "Open SnapTray and tap 'Start New Scan'",
            "Hold iPhone 60-100cm (2-3 feet) above tools",
            "Keep phone parallel to surface (not angled)",
            "Wait for green 'Plane detected' indicator",
            "Hold very steady and tap capture button",
            "Keep still for 2-3 seconds while processing"
        ],
        tips: [
            "Use both hands or a tripod for stability",
            "Ensure all tools are visible in camera view",
            "The entire workspace should fit in frame"
        ],
        warnings: [
            "Don't move phone during capture",
            "If plane not detected after 10 seconds, adjust lighting or background"
        ]
    ),

    TutorialStep(
        title: "Review & Edit Tools",
        description: "Check detected tools and adjust settings.",
        icon: "checklist",
        instructions: [
            "Verify all tools were detected (colored outlines)",
            "Tap any tool to add a label or adjust depth",
            "Toggle tools on/off if needed",
            "Tap gear icon to adjust tray settings",
            "Set material type (PLA, PETG, TPU, etc.)",
            "Adjust XY interference for desired fit"
        ],
        tips: [
            "Label tools now - easier than later",
            "Start with default interference, adjust after test print",
            "Check depth measurements look reasonable"
        ],
        warnings: [
            "Missing tools? Rescan with better lighting/contrast"
        ]
    ),

    TutorialStep(
        title: "Export Files",
        description: "Generate files for 3D printing or foam cutting.",
        icon: "square.and.arrow.up.fill",
        instructions: [
            "Tap 'Continue' to proceed to export",
            "Choose your export format:",
            "  • STL for 3D printing",
            "  • DXF for laser/CNC cutting",
            "  • PDF for scale verification",
            "Share files via AirDrop, Files app, or email"
        ],
        tips: [
            "Export all formats for backup",
            "Print PDF first to verify scale",
            "Keep STL files organized by project"
        ],
        warnings: []
    ),

    TutorialStep(
        title: "Verify Scale (Important!)",
        description: "Before printing, verify your scan's accuracy.",
        icon: "ruler.fill",
        instructions: [
            "Open the exported PDF",
            "Print page 3 (scale calibration) at 100% size",
            "Use a ruler to measure the 100mm scale bar",
            "Should measure exactly 100mm",
            "If off by >2mm, check printer settings and reprint PDF"
        ],
        tips: [
            "This step prevents wasted filament",
            "Keep calibration page for future reference"
        ],
        warnings: [
            "NEVER use 'Fit to Page' when printing PDF",
            "If scale is wrong, your tray won't fit tools properly"
        ]
    ),

    TutorialStep(
        title: "3D Print Your Tray",
        description: "Slice and print your custom tray.",
        icon: "printer.fill",
        instructions: [
            "Open STL file in your slicer (Cura, PrusaSlicer, etc.)",
            "Use recommended settings from Printing Guide",
            "For Ender 3: 0.2mm layer, 4 walls, 15% infill",
            "Print a small test tray first",
            "Test fit tools and adjust interference if needed"
        ],
        tips: [
            "PLA is easiest for beginners",
            "PETG is more durable for heavy use",
            "Add a brim for large trays to prevent warping"
        ],
        warnings: [
            "First print may need fit adjustments",
            "Keep notes on what works for YOUR printer"
        ]
    ),

    TutorialStep(
        title: "You're Ready!",
        description: "You now know how to use SnapTray. Happy scanning!",
        icon: "checkmark.circle.fill",
        instructions: [
            "Return to Home tab to start your first scan",
            "Check Projects tab to see past scans",
            "Visit Settings to customize app preferences",
            "Refer back to this tutorial anytime"
        ],
        tips: [
            "Experiment with different materials and settings",
            "Share your tray designs with the community",
            "Each scan gets better as you learn"
        ],
        warnings: []
    )
]
