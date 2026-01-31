import SwiftUI

struct AICompanionView: View {
    @Binding var decision: Decision
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var hasAcceptedDisclosure = false
    @State private var suggestions: [OptionSuggestions] = []
    @State private var errorMessage: String?
    @State private var addedSuggestions: Set<String> = []

    private var rateLimitStatus: AIService.RateLimitStatus {
        AIService.shared.getRateLimitStatus(for: decision.id)
    }

    var body: some View {
        NavigationView {
            Group {
                if !hasAcceptedDisclosure {
                    disclosureView
                } else if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if suggestions.isEmpty {
                    emptyView
                } else {
                    suggestionsListView
                }
            }
            .navigationTitle("AI Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Disclosure View

    private var disclosureView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundColor(.purple)

            // Title
            Text("Devil's Advocate")
                .font(.title)
                .fontWeight(.bold)

            // Description
            Text("Get AI-powered suggestions for pros and cons you might have missed.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Usage limits
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(rateLimitStatus.dailyRemaining)/\(rateLimitStatus.dailyLimit)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(rateLimitStatus.dailyRemaining > 0 ? .primary : .red)
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(rateLimitStatus.decisionRemaining)/\(rateLimitStatus.decisionLimit)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(rateLimitStatus.decisionRemaining > 0 ? .primary : .red)
                    Text("This Decision")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Disclosure
            VStack(alignment: .leading, spacing: 12) {
                Label("Data Disclosure", systemImage: "exclamationmark.shield")
                    .font(.headline)
                    .foregroundColor(.orange)

                Text("To provide suggestions, your decision content (titles, options, and existing pros/cons) will be sent to Google Gemini, our AI provider.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("This data is used only to generate suggestions and is not stored by Google.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if rateLimitStatus.canMakeRequest {
                    Button(action: acceptAndFetch) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("I Understand, Get Suggestions")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text(rateLimitStatus.dailyRemaining == 0 ? "Daily limit reached" : "Decision limit reached")
                            .font(.headline)
                            .foregroundColor(.red)

                        if rateLimitStatus.dailyRemaining == 0, let resetTime = rateLimitStatus.resetTime {
                            Text("Resets at \(resetTime, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                }

                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing your decision...")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("The AI is thinking of what you might have missed")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                fetchSuggestions()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Looking good!")
                .font(.headline)

            Text("The AI couldn't find any obvious pros or cons you've missed. Your analysis seems thorough!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Suggestions List View

    private var suggestionsListView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("Suggestions Found")
                        .font(.headline)
                    Text("Tap to add any suggestion to your decision")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Suggestions by option
                ForEach(suggestions) { optionSuggestion in
                    optionSuggestionsCard(optionSuggestion)
                }

                // Done button
                Button(action: { dismiss() }) {
                    Text("Done")
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
        }
    }

    private func optionSuggestionsCard(_ optionSuggestion: OptionSuggestions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Option header
            HStack {
                Text(optionSuggestion.optionLabel)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(4)

                Text(optionSuggestion.optionTitle)
                    .font(.headline)
            }

            // Suggested Pros
            if !optionSuggestion.suggestedPros.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Suggested Pros", systemImage: "hand.thumbsup.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)

                    ForEach(optionSuggestion.suggestedPros, id: \.self) { pro in
                        suggestionRow(
                            text: pro,
                            type: .pro,
                            optionIndex: optionSuggestion.optionIndex
                        )
                    }
                }
            }

            // Suggested Cons
            if !optionSuggestion.suggestedCons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Suggested Cons", systemImage: "hand.thumbsdown.fill")
                        .font(.subheadline)
                        .foregroundColor(.red)

                    ForEach(optionSuggestion.suggestedCons, id: \.self) { con in
                        suggestionRow(
                            text: con,
                            type: .con,
                            optionIndex: optionSuggestion.optionIndex
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func suggestionRow(text: String, type: ProCon.ProConType, optionIndex: Int) -> some View {
        let isAdded = addedSuggestions.contains("\(optionIndex)-\(type)-\(text)")

        return Button(action: {
            addSuggestion(text: text, type: type, optionIndex: optionIndex)
        }) {
            HStack {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundColor(isAdded ? .green : (type == .pro ? .green : .red))

                Text(text)
                    .font(.subheadline)
                    .foregroundColor(isAdded ? .secondary : .primary)
                    .strikethrough(isAdded)

                Spacer()

                if isAdded {
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .disabled(isAdded)
    }

    // MARK: - Actions

    private func acceptAndFetch() {
        hasAcceptedDisclosure = true
        fetchSuggestions()
    }

    private func fetchSuggestions() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response = try await AIService.shared.getSuggestions(for: decision)
                await MainActor.run {
                    // Convert response to option-based suggestions
                    var optionSuggestions: [OptionSuggestions] = []

                    for (index, option) in decision.options.enumerated() {
                        let label = decision.optionLabel(at: index)
                        let title = option.title.isEmpty ? "Option \(label)" : option.title

                        // Get suggestions for this specific option by label
                        let suggestionData = response.optionSuggestions[label]
                        let prosForOption = suggestionData?.pros ?? []
                        let consForOption = suggestionData?.cons ?? []

                        if !prosForOption.isEmpty || !consForOption.isEmpty {
                            optionSuggestions.append(OptionSuggestions(
                                optionIndex: index,
                                optionLabel: label,
                                optionTitle: title,
                                suggestedPros: prosForOption,
                                suggestedCons: consForOption
                            ))
                        }
                    }

                    suggestions = optionSuggestions
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func addSuggestion(text: String, type: ProCon.ProConType, optionIndex: Int) {
        guard optionIndex < decision.options.count else { return }

        let key = "\(optionIndex)-\(type)-\(text)"
        addedSuggestions.insert(key)

        let proCon = ProCon(text: text, addedBy: "AI", type: type)

        switch type {
        case .pro:
            decision.options[optionIndex].pros.append(proCon)
        case .con:
            decision.options[optionIndex].cons.append(proCon)
        }
    }
}

// MARK: - Preview

struct AICompanionView_Previews: PreviewProvider {
    static var previews: some View {
        AICompanionView(
            decision: .constant(Decision(
                title: "New Laptop",
                options: [
                    Option(
                        title: "MacBook Pro",
                        pros: [ProCon(text: "Great display", type: .pro)],
                        cons: [ProCon(text: "Expensive", type: .con)]
                    ),
                    Option(
                        title: "ThinkPad",
                        pros: [ProCon(text: "Good keyboard", type: .pro)],
                        cons: []
                    )
                ]
            ))
        )
    }
}
