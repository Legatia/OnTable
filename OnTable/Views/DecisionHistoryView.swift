import SwiftUI

struct DecisionHistoryView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) private var dismiss

    @State private var viewMode: ViewMode = .timeline
    @State private var filterOutcome: OutcomeRating? = nil
    @State private var selectedPeriod: TimePeriod = .all

    enum ViewMode {
        case timeline, stats
    }

    enum TimePeriod: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        case all = "All Time"
    }

    private var filteredDecisions: [Decision] {
        var decisions = databaseService.decisions

        // Filter by period
        let now = Date()
        switch selectedPeriod {
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
            decisions = decisions.filter { $0.createdAt >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!
            decisions = decisions.filter { $0.createdAt >= monthAgo }
        case .year:
            let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!
            decisions = decisions.filter { $0.createdAt >= yearAgo }
        case .all:
            break
        }

        // Filter by outcome
        if let outcome = filterOutcome {
            decisions = decisions.filter { $0.outcome?.rating == outcome }
        }

        return decisions.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // View mode picker
                Picker("View Mode", selection: $viewMode) {
                    Label("Timeline", systemImage: "clock").tag(ViewMode.timeline)
                    Label("Stats", systemImage: "chart.bar").tag(ViewMode.stats)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                if viewMode == .timeline {
                    timelineView
                } else {
                    statsView
                }
            }
            .navigationTitle("Decision History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Time Period", selection: $selectedPeriod) {
                            ForEach(TimePeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }

                        Divider()

                        Picker("Outcome Filter", selection: $filterOutcome) {
                            Text("All Outcomes").tag(nil as OutcomeRating?)
                            Divider()
                            ForEach(OutcomeRating.allCases, id: \.self) { rating in
                                Text("\(rating.emoji) \(rating.label)").tag(rating as OutcomeRating?)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        ScrollView {
            if filteredDecisions.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(Array(groupedByDate.keys).sorted(by: >), id: \.self) { date in
                        Section {
                            ForEach(groupedByDate[date]!, id: \.id) { decision in
                                DecisionHistoryCard(decision: decision)
                            }
                        } header: {
                            HStack {
                                Text(formatDate(date))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private var groupedByDate: [Date: [Decision]] {
        Dictionary(grouping: filteredDecisions) { decision in
            let components = Calendar.current.dateComponents([.year, .month, .day], from: decision.createdAt)
            return Calendar.current.date(from: components)!
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Stats View

    private var statsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statCard(
                        title: "Total Decisions",
                        value: "\(filteredDecisions.count)",
                        icon: "list.bullet.rectangle",
                        color: .blue
                    )

                    statCard(
                        title: "Resolved",
                        value: "\(filteredDecisions.filter { $0.isResolved }.count)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    statCard(
                        title: "Tracked",
                        value: "\(filteredDecisions.filter { $0.outcome != nil }.count)",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple
                    )

                    statCard(
                        title: "Avg Options",
                        value: String(format: "%.1f", avgOptions),
                        icon: "square.grid.2x2",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // Outcomes breakdown
                if !outcomeCounts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Outcomes")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(OutcomeRating.allCases, id: \.self) { rating in
                                if outcomeCounts[rating] ?? 0 > 0 {
                                    outcomeRow(rating: rating, count: outcomeCounts[rating]!)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }

                // Insights
                if !filteredDecisions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Insights")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            insightRow(
                                icon: "calendar",
                                text: "You've made \(filteredDecisions.count) decision\(filteredDecisions.count == 1 ? "" : "s") \(selectedPeriod.rawValue.lowercased())"
                            )

                            if let mostCommonOutcome = outcomeCounts.max(by: { $0.value < $1.value })?.key {
                                insightRow(
                                    icon: "star.fill",
                                    text: "Most common outcome: \(mostCommonOutcome.emoji) \(mostCommonOutcome.label)"
                                )
                            }

                            let successRate = calculateSuccessRate()
                            if successRate > 0 {
                                insightRow(
                                    icon: "chart.line.uptrend.xyaxis",
                                    text: "Success rate: \(Int(successRate))% of tracked decisions rated good or great"
                                )
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var avgOptions: Double {
        guard !filteredDecisions.isEmpty else { return 0 }
        let total = filteredDecisions.reduce(0) { $0 + $1.options.count }
        return Double(total) / Double(filteredDecisions.count)
    }

    private var outcomeCounts: [OutcomeRating: Int] {
        var counts: [OutcomeRating: Int] = [:]
        for decision in filteredDecisions {
            if let rating = decision.outcome?.rating {
                counts[rating, default: 0] += 1
            }
        }
        return counts
    }

    private func calculateSuccessRate() -> Double {
        let tracked = filteredDecisions.filter { $0.outcome != nil }
        guard !tracked.isEmpty else { return 0 }

        let successful = tracked.filter { decision in
            decision.outcome?.rating == .great || decision.outcome?.rating == .good
        }.count

        return (Double(successful) / Double(tracked.count)) * 100
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func outcomeRow(rating: OutcomeRating, count: Int) -> some View {
        HStack {
            Text(rating.emoji)
                .font(.title2)

            Text(rating.label)
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(rating.color)
        }
        .padding(.vertical, 8)
    }

    private func insightRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No decisions found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Try adjusting your filters or make some decisions!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Decision History Card

struct DecisionHistoryCard: View {
    let decision: Decision
    @State private var showingDetail = false
    @State private var selectedDecision: Decision?

    var body: some View {
        Button(action: {
            selectedDecision = decision
            showingDetail = true
        }) {
            HStack(spacing: 12) {
                // Timeline indicator
                VStack {
                    Circle()
                        .fill(decision.isResolved ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 2)
                }

                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(decision.displayTitle)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        if decision.isResolved {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }

                    HStack(spacing: 12) {
                        Label("\(decision.options.count)", systemImage: "square.grid.2x2")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if decision.isResolved, let winner = decision.winningOption {
                            Text("→ \(winner.title.isEmpty ? "Option" : winner.title)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    // Outcome badge
                    if let outcome = decision.outcome {
                        HStack(spacing: 6) {
                            Text(outcome.rating.emoji)
                                .font(.caption)
                            Text(outcome.rating.label)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(outcome.rating.color.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
        }
        .sheet(item: $selectedDecision) { dec in
            NavigationView {
                DecisionView(decision: dec)
                    .environmentObject(DatabaseService.shared)
            }
        }
    }
}

// MARK: - Preview

struct DecisionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        DecisionHistoryView()
            .environmentObject(DatabaseService.shared)
    }
}
