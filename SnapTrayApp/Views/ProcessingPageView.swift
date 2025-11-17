import SwiftUI

/// Dedicated full-screen processing page with detailed progress tracking
struct ProcessingPageView: View {
    @Binding var statusMessage: String
    @Binding var progress: Double // 0.0 to 1.0
    let onComplete: () -> Void

    @State private var rotationDegrees: Double = 0

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.6),
                    Color.purple.opacity(0.6),
                    Color.pink.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .blur(radius: 100)

            VStack(spacing: 40) {
                Spacer()

                // Animated icon with rotating rings
                ZStack {
                    // Rotating rings
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white.opacity(0.8), .white.opacity(0.2)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 100 + CGFloat(index * 40), height: 100 + CGFloat(index * 40))
                            .rotationEffect(.degrees(rotationDegrees + Double(index) * 120))
                    }

                    // Center icon
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 10)
                }
                .onAppear {
                    withAnimation(Animation.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        rotationDegrees = 360
                    }
                }

                // Status and progress
                VStack(spacing: 24) {
                    // Current status message
                    Text(statusMessage)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .frame(height: 60)
                        .padding(.horizontal)

                    // Progress bar container
                    VStack(spacing: 12) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 8)

                                // Progress fill with gradient
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.white, .white.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            }
                        }
                        .frame(height: 8)
                        .frame(maxWidth: 300)

                        // Percentage
                        Text("\(Int(progress * 100))%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }

                    // Processing steps indicator
                    ProcessingStepsView(progress: progress)
                }
                .padding(40)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.1))
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.3), radius: 30)

                Spacer()
            }
            .padding()
        }
        .onChange(of: progress) { oldValue, newValue in
            if newValue >= 1.0 {
                // Small delay to show 100% before completing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}

/// Shows the current processing step with visual indicators
struct ProcessingStepsView: View {
    let progress: Double

    private var steps: [(name: String, range: ClosedRange<Double>)] {
        [
            ("Workspace Setup", 0.0...0.15),
            ("LiDAR Analysis", 0.15...0.25),
            ("Tool Detection", 0.25...0.50),
            ("Geometry Processing", 0.50...0.80),
            ("Finalizing", 0.80...1.0)
        ]
    }

    private func stepStatus(for range: ClosedRange<Double>) -> StepStatus {
        if progress > range.upperBound {
            return .completed
        } else if progress >= range.lowerBound {
            return .active
        } else {
            return .pending
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 4) {
                    // Step indicator
                    Circle()
                        .fill(stepColor(for: step.range))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        )

                    // Step name (only for active step)
                    if stepStatus(for: step.range) == .active {
                        Text(step.name)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(width: 60)
                    }
                }

                // Connecting line (except for last step)
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.top, 8)
    }

    private func stepColor(for range: ClosedRange<Double>) -> Color {
        switch stepStatus(for: range) {
        case .completed:
            return .green
        case .active:
            return .white
        case .pending:
            return .white.opacity(0.3)
        }
    }

    enum StepStatus {
        case pending
        case active
        case completed
    }
}
