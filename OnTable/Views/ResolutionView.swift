import SwiftUI

struct ResolutionView: View {
    @Binding var decision: Decision
    let onDone: () -> Void

    @State private var selectedOptionIndex: Int?
    @State private var showGutCheck = false
    @State private var hasResolved = false
    @State private var showConfetti = false
    @State private var showingShareSheet = false
    @State private var showingPaywall = false
    @ObservedObject var premiumManager = PremiumManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if decision.isAutoResolved {
                    // Only one option - auto resolved
                    autoResolvedView
                } else if hasResolved {
                    resolvedView
                } else {
                    selectionView
                }
            }
            .padding()
            .navigationTitle(hasResolved || decision.isAutoResolved ? "Decision Made!" : "Make Your Choice")
            .navigationBarTitleDisplayMode(.inline)
            .confetti(isActive: $showConfetti)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if hasResolved || decision.isAutoResolved {
                        Button("Done") {
                            onDone()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !hasResolved && !decision.isAutoResolved {
                        Button("Cancel") {
                            onDone()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheetView(decision: decision)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Auto Resolved View (Single Option)

    private var autoResolvedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Decision Made!")
                .font(.title)
                .fontWeight(.bold)

            if let option = decision.options.first {
                Text(option.title.isEmpty ? "Option A" : option.title)
                    .font(.title2)
                    .foregroundColor(.green)

                Text("Only one option remaining")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Decision saved to history")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            // Auto-resolve on appear
            if !decision.isResolved && decision.options.count == 1 {
                decision.resolve(at: 0)
            }
        }
    }

    // MARK: - Selection View

    private var selectionView: some View {
        VStack(spacing: 24) {
            // Calculated winner suggestion
            if let winnerIndex = decision.calculatedWinnerIndex {
                let winner = decision.options[winnerIndex]

                VStack(spacing: 8) {
                    Text("Based on your scores")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(winner.title.isEmpty ? "Option \(decision.optionLabel(at: winnerIndex))" : winner.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)

                    Text("is winning with \(winner.score) points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Tie
                VStack(spacing: 8) {
                    Image(systemName: "equal.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("It's a tie!")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Trust your gut")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }

            Text("Choose your winner:")
                .font(.headline)

            // Option buttons (scrollable for many options)
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(decision.options.indices, id: \.self) { index in
                        optionButton(for: index, option: decision.options[index])
                    }
                }
            }

            // Confirm button
            if let selected = selectedOptionIndex {
                Button(action: { confirmSelection(selected) }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirm Choice")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
            }
        }
        .alert("Gut Check", isPresented: $showGutCheck) {
            Button("Yes, I meant \(selectedOptionTitle)", role: .destructive) {
                if let index = selectedOptionIndex {
                    finalizeSelection(index)
                }
            }
            Button("Let me reconsider", role: .cancel) {
                selectedOptionIndex = nil
            }
        } message: {
            Text("You chose against the calculated winner. Are you sure? Sometimes your gut knows best!")
        }
    }

    private func optionButton(for index: Int, option: Option) -> some View {
        let isSelected = selectedOptionIndex == index
        let isWinner = decision.calculatedWinnerIndex == index
        let title = option.title.isEmpty ? "Option \(decision.optionLabel(at: index))" : option.title

        return Button(action: {
            HapticManager.shared.selection()
            selectedOptionIndex = index
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if isWinner {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }

                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                    }

                    Text("Score: \(option.score)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resolved View

    private var resolvedView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Celebration
            Image(systemName: "party.popper.fill")
                .font(.system(size: 64))
                .foregroundColor(.yellow)

            if let winnerIndex = decision.winningOptionIndex {
                let winner = decision.options[winnerIndex]
                let title = winner.title.isEmpty ? "Option \(decision.optionLabel(at: winnerIndex))" : winner.title

                Text("You chose")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                // Winner pros recap
                if !winner.pros.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remember why:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(winner.pros.prefix(3)) { pro in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(pro.text)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            Spacer()

            Text("Decision saved to history")
                .font(.caption)
                .foregroundColor(.secondary)

            // Share Button
            Button(action: {
                if premiumManager.features.canShare {
                    showingShareSheet = true
                } else {
                    showingPaywall = true
                }
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(premiumManager.features.canShare ? .accentColor : .secondary)
                    
                    if !premiumManager.features.canShare {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .padding(3)
                            .background(Color.white)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                .padding(12)
                .background(premiumManager.features.canShare ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                .clipShape(Circle())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private var selectedOptionTitle: String {
        guard let index = selectedOptionIndex, index < decision.options.count else { return "" }
        let option = decision.options[index]
        return option.title.isEmpty ? "Option \(decision.optionLabel(at: index))" : option.title
    }

    private func confirmSelection(_ index: Int) {
        // Check if going against calculated winner
        if let winnerIndex = decision.calculatedWinnerIndex, winnerIndex != index {
            showGutCheck = true
        } else {
            finalizeSelection(index)
        }
    }

    private func finalizeSelection(_ index: Int) {
        // Haptic feedback
        HapticManager.shared.success()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            decision.resolve(at: index)
            hasResolved = true
        }

        // Trigger confetti with slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showConfetti = true
        }
    }
}

// MARK: - Preview

struct ResolutionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ResolutionView(
                decision: .constant(Decision(
                    title: "New Phone",
                    options: [
                        Option(
                            title: "iPhone 15",
                            pros: [ProCon(text: "Great camera", weight: .bold, type: .pro)],
                            cons: [ProCon(text: "Expensive", type: .con)]
                        ),
                        Option(
                            title: "Samsung S24",
                            pros: [ProCon(text: "Better display", type: .pro)],
                            cons: []
                        ),
                        Option(
                            title: "Pixel 8",
                            pros: [],
                            cons: []
                        )
                    ]
                )),
                onDone: {}
            )
            .previewDisplayName("Selection")

            ResolutionView(
                decision: .constant(Decision(
                    title: "New Phone",
                    options: [
                        Option(title: "iPhone 15")
                    ],
                    chosenOptionId: nil
                )),
                onDone: {}
            )
            .previewDisplayName("Auto Resolved")
        }
    }
}
