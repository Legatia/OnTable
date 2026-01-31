import SwiftUI

struct OutcomeTrackingView: View {
    @Binding var decision: Decision
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRating: OutcomeRating?
    @State private var notes: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Decision summary
                    decisionSummary

                    // Rating selection
                    ratingSection

                    // Notes
                    notesSection

                    // Save button
                    saveButton
                }
                .padding()
            }
            .navigationTitle("Track Outcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Load existing outcome if any
                if let existingOutcome = decision.outcome {
                    selectedRating = existingOutcome.rating
                    notes = existingOutcome.notes
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.purple)

            Text("How did it go?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Track the outcome of your decision to learn from your choices over time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Decision Summary

    private var decisionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Decision")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if let winner = decision.winningOption {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(decision.title.isEmpty ? "Decision" : decision.title)
                            .font(.headline)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Chose: \(winner.title.isEmpty ? "Option A" : winner.title)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if let resolvedAt = decision.resolvedAt {
                            Text(resolvedAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text("\(winner.score)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(winner.score >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How was the outcome?")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(OutcomeRating.allCases, id: \.self) { rating in
                    ratingButton(rating)
                }
            }
        }
    }

    private func ratingButton(_ rating: OutcomeRating) -> some View {
        let isSelected = selectedRating == rating

        return Button(action: { selectedRating = rating }) {
            VStack(spacing: 8) {
                Text(rating.emoji)
                    .font(.system(size: 32))

                Text(rating.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? ratingColor(rating).opacity(0.2) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? ratingColor(rating) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func ratingColor(_ rating: OutcomeRating) -> Color {
        switch rating {
        case .great: return .green
        case .good: return .blue
        case .neutral: return .gray
        case .regret: return .orange
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (optional)")
                .font(.headline)

            Text("What did you learn? Would you decide differently?")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $notes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: save) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(decision.hasOutcome ? "Update Outcome" : "Save Outcome")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(selectedRating != nil ? Color.purple : Color.gray)
            .cornerRadius(12)
        }
        .disabled(selectedRating == nil)
    }

    // MARK: - Actions

    private func save() {
        guard let rating = selectedRating else { return }
        decision.trackOutcome(rating: rating, notes: notes)
        dismiss()
    }
}

// MARK: - Outcome Badge (for use in lists)

struct OutcomeBadge: View {
    let outcome: DecisionOutcome

    var body: some View {
        HStack(spacing: 4) {
            Text(outcome.rating.emoji)
                .font(.caption)
            Text(outcome.rating.label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var badgeColor: Color {
        switch outcome.rating {
        case .great: return .green
        case .good: return .blue
        case .neutral: return .gray
        case .regret: return .orange
        }
    }
}

// MARK: - Preview

struct OutcomeTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        OutcomeTrackingView(
            decision: .constant(Decision(
                title: "New Phone",
                options: [
                    Option(title: "iPhone 15", pros: [ProCon(text: "Camera", type: .pro)]),
                    Option(title: "Samsung", pros: [])
                ],
                resolvedAt: Date(),
                chosenOptionId: nil
            ))
        )
    }
}
