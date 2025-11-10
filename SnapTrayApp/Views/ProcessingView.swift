import SwiftUI

struct ProcessingView: View {
    let statusMessage: String
    let progress: Double // 0.0 to 1.0

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

            // Glass morphism effect
            ZStack {
                VStack(spacing: 30) {
                    // Animated icon
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
                                .frame(width: 80 + CGFloat(index * 30), height: 80 + CGFloat(index * 30))
                                .rotationEffect(.degrees(Double(index) * 120))
                                .animation(
                                    Animation.linear(duration: 3.0 - Double(index) * 0.5)
                                        .repeatForever(autoreverses: false),
                                    value: index
                                )
                        }

                        // Center icon
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.5), radius: 10)
                    }

                    // Status text
                    VStack(spacing: 12) {
                        Text(statusMessage)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2)

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 6)

                                // Progress
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.white, .white.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                                    .animation(.easeInOut(duration: 0.3), value: progress)
                            }
                        }
                        .frame(width: 200, height: 6)

                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(50)
                .background(.ultraThinMaterial)
                .background(Color.white.opacity(0.1))
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.3), radius: 30)
            }
        }
    }
}

#Preview {
    ProcessingView(statusMessage: "Analyzing depth data...", progress: 0.65)
}
