import SwiftUI

struct ShareSheetView: View {
    let decision: Decision
    @ObservedObject var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTemplate: ShareCardTemplate = .classic
    @State private var backgroundImage: UIImage?
    @State private var showingImagePicker = false
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var showingPaywall = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Preview
                ShareCardView(
                    decision: decision,
                    isPremium: premiumManager.isPremium,
                    template: selectedTemplate,
                    backgroundImage: backgroundImage,
                    imageScale: imageScale,
                    imageOffset: imageOffset
                )
                .gesture(
                    selectedTemplate == .custom ?
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                let newScale = imageScale * delta
                                imageScale = min(max(newScale, 1.0), 5.0)
                            }
                            .onEnded { _ in lastScale = 1.0 },
                        DragGesture()
                            .onChanged { value in
                                imageOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { value in
                                lastOffset = imageOffset
                            }
                    ) : nil
                )
                .onTapGesture {
                    if selectedTemplate == .custom {
                        showingImagePicker = true
                    }
                }
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
                            ForEach(ShareCardTemplate.allCases, id: \.self) { template in
                                TemplateButton(
                                    template: template,
                                    isSelected: selectedTemplate == template,
                                    isLocked: !premiumManager.isTemplateUnlocked(template),
                                    action: {
                                        if template == .custom {
                                            selectedTemplate = template
                                            if backgroundImage == nil {
                                                showingImagePicker = true
                                            }
                                        } else {
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
                            showingPaywall = true
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
                Button(action: {
                    if isTemplateUnlocked {
                        shareCard()
                    } else {
                        showingPaywall = true
                    }
                }) {
                    HStack {
                        if !isTemplateUnlocked {
                            Image(systemName: "lock.fill")
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isTemplateUnlocked ? "Share to Social" : "Unlock Template")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTemplateUnlocked ? Color.accentColor : Color.orange)
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
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $backgroundImage)
                .onDisappear {
                    // Reset transform when new image picked
                    imageScale = 1.0
                    imageOffset = .zero
                    lastOffset = .zero
                    lastScale = 1.0
                }
        }
    }

    private var isTemplateUnlocked: Bool {
        premiumManager.isTemplateUnlocked(selectedTemplate)
    }

    private func shareCard() {
        ShareService.shared.shareDecision(
            decision,
            isPremium: premiumManager.isPremium,
            template: selectedTemplate,
            backgroundImage: backgroundImage,
            imageScale: imageScale,
            imageOffset: imageOffset
        )
    }
}

// MARK: - Template Button

struct TemplateButton: View {
    let template: ShareCardTemplate
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Template preview mini
                ZStack {
                    templatePreview

                    if isLocked {
                        Color.black.opacity(0.5)
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()
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
        case .custom:
            ZStack {
                Color.gray
                Image(systemName: "photo")
                    .foregroundColor(.white)
            }
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
