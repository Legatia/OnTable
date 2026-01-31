import SwiftUI

struct ShareSheetView: View {
    let decision: Decision
    @ObservedObject var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: ShareCardView.CardTemplate = .classic

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Preview
                ShareCardView(
                    decision: decision,
                    isPremium: premiumManager.isPremium,
                    template: selectedTemplate
                )
                .scaleEffect(0.8)
                .frame(height: 340)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)

                // Template selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ShareCardView.CardTemplate.allCases, id: \.self) { template in
                                TemplateButton(
                                    template: template,
                                    isSelected: selectedTemplate == template,
                                    isLocked: template.isPremiumOnly && !premiumManager.isPremium,
                                    action: {
                                        if !template.isPremiumOnly || premiumManager.isPremium {
                                            selectedTemplate = template
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Premium upsell (if not premium)
                if !premiumManager.isPremium {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("Upgrade to remove watermark & unlock all templates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Upgrade") {
                            // TODO: Show paywall
                        }
                        .font(Font.caption.weight(.semibold))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Spacer()

                // Share button
                Button(action: shareCard) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share to Social")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Share Decision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func shareCard() {
        ShareService.shared.shareDecision(
            decision,
            isPremium: premiumManager.isPremium,
            template: selectedTemplate
        )
    }
}

// MARK: - Template Button

struct TemplateButton: View {
    let template: ShareCardView.CardTemplate
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Template preview mini
                ZStack {
                    templatePreview
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)

                    if isLocked {
                        Color.black.opacity(0.5)
                            .cornerRadius(8)
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )

                Text(template.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .opacity(isLocked ? 0.7 : 1)
    }

    @ViewBuilder
    private var templatePreview: some View {
        switch template {
        case .classic:
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .minimal:
            Color.white
        case .bold:
            LinearGradient(
                colors: [.purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunset:
            LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .top,
                endPoint: .bottom
            )
        case .ocean:
            LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .forest:
            LinearGradient(
                colors: [Color.green.opacity(0.6), Color.green.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .neon:
            Color.black
        case .paper:
            Color(red: 0.98, green: 0.96, blue: 0.92)
        }
    }
}

// MARK: - Preview

struct ShareSheetView_Previews: PreviewProvider {
    static var previews: some View {
        ShareSheetView(
            decision: Decision(
                title: "Weekend Plans",
                options: [
                    Option(
                        title: "Beach",
                        pros: [ProCon(text: "Relaxing", type: .pro)],
                        cons: [ProCon(text: "Crowded", type: .con)]
                    ),
                    Option(
                        title: "Mountains",
                        pros: [ProCon(text: "Peaceful", type: .pro)],
                        cons: []
                    )
                ]
            )
        )
    }
}
