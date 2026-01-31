import SwiftUI

struct ShareCardView: View {
    let decision: Decision
    let isPremium: Bool
    let template: CardTemplate

    enum CardTemplate: String, CaseIterable {
        case classic = "Classic"
        case minimal = "Minimal"
        case bold = "Bold"
        // Premium templates
        case sunset = "Sunset"
        case ocean = "Ocean"
        case forest = "Forest"
        case neon = "Neon"
        case paper = "Paper"

        var isPremiumOnly: Bool {
            switch self {
            case .classic, .minimal, .bold: return false
            case .sunset, .ocean, .forest, .neon, .paper: return true
            }
        }
    }

    var body: some View {
        ZStack {
            // Background
            templateBackground

            // Content
            VStack(spacing: 0) {
                // Header with title and stats
                VStack(spacing: 8) {
                    if !decision.title.isEmpty {
                        Text(decision.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(textColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Decision stats
                    HStack(spacing: 16) {
                        statBadge(
                            icon: "list.bullet",
                            value: "\(decision.options.count)",
                            label: "options"
                        )

                        let totalPros = decision.options.reduce(0) { $0 + $1.pros.count }
                        let totalCons = decision.options.reduce(0) { $0 + $1.cons.count }

                        statBadge(
                            icon: "plus.circle.fill",
                            value: "\(totalPros)",
                            label: "pros",
                            color: .green
                        )

                        statBadge(
                            icon: "minus.circle.fill",
                            value: "\(totalCons)",
                            label: "cons",
                            color: .red
                        )
                    }
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
                }
                .padding(.top, 32)
                .padding(.bottom, 16)

                Spacer()

                // Options Section
                if decision.options.count <= 2 {
                    // 2 options: side by side
                    twoOptionsView
                } else {
                    // 3+ options: show winner vs runner-up or grid
                    multiOptionsView
                }

                Spacer()

                // Bottom section with outcome and branding
                VStack(spacing: 12) {
                    // Outcome rating if available
                    if let outcome = decision.outcome {
                        HStack(spacing: 8) {
                            Text(outcome.rating.emoji)
                                .font(.title2)
                            Text("Outcome: \(outcome.rating.label)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(textColor)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(textColor.opacity(0.1))
                        .cornerRadius(20)
                    } else if decision.isResolved, let winner = decision.winningOption {
                        // Status text
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("I chose \(winner.title.isEmpty ? "this" : winner.title)!")
                        }
                        .font(.headline)
                        .foregroundColor(accentColor)
                    } else {
                        Text("Help me decide!")
                            .font(.headline)
                            .foregroundColor(textColor)
                    }

                    // Branding (always visible, styled better)
                    brandingView
                }
                .padding(.bottom, 28)
            }
        }
        .frame(width: 400, height: 400) // 1:1 aspect ratio
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Two Options View

    private var twoOptionsView: some View {
        HStack(spacing: 16) {
            // First option
            if let first = decision.options.first {
                optionView(first, index: 0)
            }

            // VS divider
            Text("vs")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(textColor.opacity(0.5))

            // Second option
            if decision.options.count > 1 {
                optionView(decision.options[1], index: 1)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Multi Options View

    private var multiOptionsView: some View {
        VStack(spacing: 12) {
            // Show top 2 options or winner + runner-up
            let sortedIndices = decision.options.indices.sorted { decision.options[$0].score > decision.options[$1].score }

            HStack(spacing: 12) {
                if sortedIndices.count >= 1 {
                    optionView(decision.options[sortedIndices[0]], index: sortedIndices[0], compact: true)
                }

                Text("vs")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(textColor.opacity(0.5))

                if sortedIndices.count >= 2 {
                    optionView(decision.options[sortedIndices[1]], index: sortedIndices[1], compact: true)
                }
            }
            .padding(.horizontal, 24)

            // Show "+N more" if more than 2 options
            if decision.options.count > 2 {
                Text("+\(decision.options.count - 2) more option\(decision.options.count > 3 ? "s" : "")")
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.5))
            }
        }
    }

    // MARK: - Helper Views

    private func statBadge(icon: String, value: String, label: String, color: Color? = nil) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .fontWeight(.semibold)
            Text(label)
        }
        .foregroundColor(color?.opacity(0.8) ?? textColor.opacity(0.6))
    }

    private var brandingView: some View {
        HStack(spacing: 6) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 14))
            Text("Made with OnTable")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundColor(isPremium ? textColor.opacity(0.5) : accentColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isPremium ? textColor.opacity(0.08) : accentColor.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isPremium ? textColor.opacity(0.1) : accentColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Option View

    private func optionView(_ option: Option, index: Int, compact: Bool = false) -> some View {
        let isWinner = decision.isResolved && decision.chosenOptionId == option.id

        return VStack(spacing: compact ? 4 : 8) {
            // Winner crown
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(compact ? .caption : .title3)
                    .foregroundColor(.yellow)
            }

            // Title
            Text(option.title.isEmpty ? decision.optionLabel(at: index) : option.title)
                .font(compact ? .subheadline : .title3)
                .fontWeight(.bold)
                .foregroundColor(textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Score
            Text("\(option.score)")
                .font(.system(size: compact ? 24 : 32, weight: .heavy, design: .rounded))
                .foregroundColor(isWinner ? accentColor : textColor.opacity(0.7))

            // Pro/con count
            HStack(spacing: compact ? 4 : 8) {
                Label("\(option.pros.count)", systemImage: "plus.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Label("\(option.cons.count)", systemImage: "minus.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 12 : 16)
        .background(isWinner ? accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(16)
    }

    // MARK: - Template Styling

    @ViewBuilder
    private var templateBackground: some View {
        switch template {
        case .classic:
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.95, blue: 0.97),
                    Color(red: 0.88, green: 0.90, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .minimal:
            Color.white
        case .bold:
            LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.4, blue: 0.95),  // Purple
                    Color(red: 0.95, green: 0.45, blue: 0.65)  // Pink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunset:
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.45, blue: 0.35),  // Coral
                    Color(red: 1.0, green: 0.65, blue: 0.35),  // Orange
                    Color(red: 0.95, green: 0.85, blue: 0.45)  // Yellow
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .ocean:
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.4, blue: 0.7),   // Deep blue
                    Color(red: 0.2, green: 0.7, blue: 0.85),  // Cyan
                    Color(red: 0.5, green: 0.9, blue: 0.9)    // Light cyan
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .forest:
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.35, blue: 0.25), // Dark green
                    Color(red: 0.35, green: 0.65, blue: 0.45), // Forest green
                    Color(red: 0.55, green: 0.85, blue: 0.65)  // Light green
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .neon:
            ZStack {
                Color.black
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.0, blue: 0.8).opacity(0.3),
                        Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .paper:
            Color(red: 0.98, green: 0.96, blue: 0.92)
        }
    }

    private var textColor: Color {
        switch template {
        case .classic, .minimal, .paper:
            return .primary
        case .bold, .sunset, .ocean, .forest, .neon:
            return .white
        }
    }

    private var accentColor: Color {
        switch template {
        case .classic, .minimal:
            return Color(red: 0.282, green: 0.537, blue: 0.894)  // Brand blue
        case .bold:
            return Color(red: 1.0, green: 0.85, blue: 0.2)  // Bright yellow
        case .sunset:
            return Color(red: 1.0, green: 1.0, blue: 0.8)  // Light yellow
        case .ocean:
            return Color(red: 0.8, green: 1.0, blue: 1.0)  // Light cyan
        case .forest:
            return Color(red: 0.8, green: 1.0, blue: 0.85)  // Light green
        case .neon:
            return Color(red: 0.0, green: 1.0, blue: 0.9)  // Bright cyan
        case .paper:
            return Color(red: 0.85, green: 0.45, blue: 0.2)  // Burnt orange
        }
    }
}

// MARK: - Preview

struct ShareCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ShareCardView(
                decision: Decision(
                    title: "Dinner Tonight",
                    options: [
                        Option(
                            title: "Pizza",
                            pros: [ProCon(text: "Tasty", type: .pro), ProCon(text: "Quick", type: .pro)],
                            cons: [ProCon(text: "Unhealthy", type: .con)]
                        ),
                        Option(
                            title: "Salad",
                            pros: [ProCon(text: "Healthy", type: .pro)],
                            cons: [ProCon(text: "Boring", type: .con)]
                        )
                    ]
                ),
                isPremium: false,
                template: .classic
            )
            .padding()
            .background(Color.gray)
            .previewDisplayName("Classic - Free")

            ShareCardView(
                decision: Decision(
                    title: "New Phone",
                    options: [
                        Option(
                            title: "iPhone",
                            pros: [ProCon(text: "Camera", weight: .bold, type: .pro)],
                            cons: []
                        ),
                        Option(
                            title: "Android",
                            pros: [],
                            cons: [ProCon(text: "Updates", type: .con)]
                        ),
                        Option(
                            title: "Pixel",
                            pros: [ProCon(text: "Pure Android", type: .pro)],
                            cons: []
                        )
                    ]
                ),
                isPremium: true,
                template: .bold
            )
            .padding()
            .background(Color.gray)
            .previewDisplayName("Bold - Multi Options")
        }
    }
}
