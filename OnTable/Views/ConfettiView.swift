import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<50, id: \.self) { index in
                    ConfettiPiece(
                        color: colors[index % colors.count],
                        geometry: geometry
                    )
                    .opacity(animate ? 0 : 1)
                    .offset(
                        x: animate ? randomOffset(max: geometry.size.width) : 0,
                        y: animate ? geometry.size.height + 100 : -100
                    )
                    .rotationEffect(.degrees(animate ? Double.random(in: 0...720) : 0))
                    .animation(
                        Animation
                            .easeOut(duration: Double.random(in: 1.5...3.0))
                            .delay(Double(index) * 0.02),
                        value: animate
                    )
                }
            }
        }
        .onAppear {
            animate = true
        }
        .allowsHitTesting(false)
    }

    private func randomOffset(max: CGFloat) -> CGFloat {
        CGFloat.random(in: -max/2...max/2)
    }
}

struct ConfettiPiece: View {
    let color: Color
    let geometry: GeometryProxy

    var body: some View {
        let size = CGFloat.random(in: 8...16)
        let shape = Int.random(in: 0...2)

        Group {
            if shape == 0 {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            } else if shape == 1 {
                Rectangle()
                    .fill(color)
                    .frame(width: size, height: size)
            } else {
                Triangle()
                    .fill(color)
                    .frame(width: size, height: size)
            }
        }
        .position(
            x: CGFloat.random(in: 0...geometry.size.width),
            y: 0
        )
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Confetti Modifier

struct ConfettiModifier: ViewModifier {
    @Binding var isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        ConfettiView()
                    }
                }
            )
            .onChange(of: isActive) { newValue in
                if newValue {
                    // Auto-dismiss after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isActive = false
                    }
                }
            }
    }
}

extension View {
    func confetti(isActive: Binding<Bool>) -> some View {
        modifier(ConfettiModifier(isActive: isActive))
    }
}
