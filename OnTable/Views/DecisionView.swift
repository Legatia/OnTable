import SwiftUI

struct DecisionView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) private var dismiss

    @State var decision: Decision
    @State private var showingResolution = false
    @State private var showingHostRoom = false
    @State private var showingJoinRoom = false
    @State private var showingRoom = false
    @State private var showingShareSheet = false
    @State private var showingPaywall = false
    @State private var showingAICompanion = false
    @State private var showingOutcomeTracking = false
    @State private var currentPage = 0

    @ObservedObject private var roomService = RoomService.shared
    @ObservedObject private var premiumManager = PremiumManager.shared

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Title bar (optional)
                if !decision.title.isEmpty {
                    Text(decision.title)
                        .font(.headline)
                        .padding(.vertical, 8)
                }

                // Split view
                splitView(geometry: geometry)

                // Bottom toolbar
                bottomToolbar
            }
        }
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Host Room - requires Starter+
                    if premiumManager.features.canHostRoom {
                        Button(action: { showingHostRoom = true }) {
                            Label("Host Room", systemImage: "person.2.badge.gearshape")
                        }
                    } else {
                        Button(action: { showingPaywall = true }) {
                            Label("Host Room", systemImage: "lock.fill")
                        }
                    }

                    // Join Room - everyone can join
                    Button(action: { showingJoinRoom = true }) {
                        Label("Join Room", systemImage: "qrcode.viewfinder")
                    }

                    Divider()

                    // Share Card - requires Starter+
                    if premiumManager.features.canShare {
                        Button(action: shareDecision) {
                            Label("Share Card", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button(action: { showingPaywall = true }) {
                            Label("Share Card", systemImage: "lock.fill")
                        }
                    }

                    Divider()

                    // AI Companion - requires Premium
                    if premiumManager.features.hasAICompanion {
                        Button(action: { showingAICompanion = true }) {
                            Label("AI Companion", systemImage: "sparkles")
                        }
                    } else {
                        Button(action: { showingPaywall = true }) {
                            Label("AI Companion", systemImage: "lock.fill")
                        }
                    }

                    // Outcome Tracking - requires Premium, only for resolved decisions
                    if decision.isResolved {
                        if premiumManager.features.hasOutcomeTracking {
                            Button(action: { showingOutcomeTracking = true }) {
                                Label(
                                    decision.hasOutcome ? "Update Outcome" : "Track Outcome",
                                    systemImage: "chart.line.uptrend.xyaxis"
                                )
                            }
                        } else {
                            Button(action: { showingPaywall = true }) {
                                Label("Track Outcome", systemImage: "lock.fill")
                            }
                        }
                    }

                    Divider()

                    // Settings/Upgrade
                    Button(action: { showingPaywall = true }) {
                        Label(premiumManager.currentTier == .free ? "Upgrade" : "Manage Plan", systemImage: "crown")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onChange(of: decision) { newValue in
            databaseService.saveDecision(newValue)
        }
        .sheet(isPresented: $showingResolution) {
            ResolutionView(decision: $decision, onDone: {
                databaseService.saveDecision(decision)
                dismiss()
            })
        }
        .sheet(isPresented: $showingHostRoom) {
            QRDisplayView(decision: decision)
        }
        .sheet(isPresented: $showingJoinRoom) {
            QRScannerView()
        }
        .fullScreenCover(isPresented: $showingRoom) {
            RoomView(decision: $decision, isHost: roomService.isHosting)
                .environmentObject(databaseService)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheetView(decision: decision)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingAICompanion) {
            AICompanionView(decision: $decision)
        }
        .sheet(isPresented: $showingOutcomeTracking) {
            OutcomeTrackingView(decision: $decision)
        }
        .onChange(of: roomService.isHosting) { isHosting in
            if isHosting && !roomService.connectedPeers.isEmpty {
                showingHostRoom = false
                showingRoom = true
            }
        }
        .onChange(of: roomService.isJoined) { isJoined in
            if isJoined {
                showingJoinRoom = false
                showingRoom = true
            }
        }
    }

    // MARK: - Split View

    @ViewBuilder
    private func splitView(geometry: GeometryProxy) -> some View {
        let isLandscape = geometry.size.width > geometry.size.height
        // Guard against zero/negative widths during initial layout
        let cardWidth = max(100, isLandscape
            ? (geometry.size.width - 36) / 2
            : geometry.size.width - 32)

        if isLandscape {
            // Side by side in landscape (show first 2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(decision.options.indices, id: \.self) { index in
                        OptionCard(
                            option: $decision.options[index],
                            optionLabel: decision.optionLabel(at: index),
                            canDelete: decision.options.count > 1,
                            onDelete: { deleteOption(at: index) }
                        )
                        .frame(width: cardWidth)
                    }

                    // Add option button
                    addOptionCard
                        .frame(width: cardWidth)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        } else {
            // Stacked in portrait with tabs
            ZStack(alignment: .bottom) {
                TabView(selection: $currentPage) {
                    ForEach(decision.options.indices, id: \.self) { index in
                        ScrollView {
                            OptionCard(
                                option: $decision.options[index],
                                optionLabel: decision.optionLabel(at: index),
                                canDelete: decision.options.count > 1,
                                onDelete: { deleteOption(at: index) }
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .tag(index)
                    }

                    // Add option page
                    ScrollView {
                        addOptionCard
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .tag(decision.options.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Custom page indicator with option count
                HStack(spacing: 8) {
                    ForEach(0..<decision.options.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    // Add button indicator
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(currentPage == decision.options.count ? Color.accentColor : Color.secondary.opacity(0.5))
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Add Option Card

    private var canAddMoreOptions: Bool {
        decision.options.count < premiumManager.features.maxOptions
    }

    private var addOptionCard: some View {
        Button(action: addNewOption) {
            VStack(spacing: 16) {
                if canAddMoreOptions {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("Add Option")
                        .font(.headline)
                        .foregroundColor(.accentColor)

                    Text("Compare more choices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Upgrade prompt for free users
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Unlock More Options")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Upgrade to Starter to compare unlimited choices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("From $2.99/mo")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            // Score comparison (scrollable if many options)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(decision.options.indices, id: \.self) { index in
                        if index > 0 {
                            Text("vs")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        scoreLabel(for: decision.options[index], index: index)
                    }
                }
            }

            Spacer()

            // Decide button
            Button(action: {
                if decision.options.count == 1 {
                    // Auto-resolve with single option
                    decision.resolve(at: 0)
                    databaseService.saveDecision(decision)
                    dismiss()
                } else {
                    showingResolution = true
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Decide")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(24)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func scoreLabel(for option: Option, index: Int) -> some View {
        let isWinning = decision.calculatedWinnerIndex == index

        return VStack(spacing: 2) {
            Text(option.title.isEmpty ? decision.optionLabel(at: index) : option.title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text("\(option.score)")
                .font(.headline)
                .fontWeight(isWinning ? .bold : .regular)
                .foregroundColor(isWinning ? .green : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isWinning ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func addNewOption() {
        if canAddMoreOptions {
            decision.addOption()
            currentPage = decision.options.count - 1
        } else {
            showingPaywall = true
        }
    }

    private func deleteOption(at index: Int) {
        decision.removeOption(at: index)
        if currentPage >= decision.options.count {
            currentPage = max(0, decision.options.count - 1)
        }
    }

    private func shareDecision() {
        showingShareSheet = true
    }
}

// MARK: - Preview

struct DecisionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DecisionView(
                decision: Decision(
                    title: "New Phone",
                    options: [
                        Option(
                            title: "iPhone 15",
                            pros: [
                                ProCon(text: "Great camera", weight: .bold, type: .pro),
                                ProCon(text: "iOS ecosystem", type: .pro)
                            ],
                            cons: [
                                ProCon(text: "Expensive", type: .con)
                            ]
                        ),
                        Option(
                            title: "Samsung S24",
                            pros: [
                                ProCon(text: "Better display", type: .pro)
                            ],
                            cons: [
                                ProCon(text: "Less reliable updates", type: .con)
                            ]
                        ),
                        Option(
                            title: "Pixel 8",
                            pros: [
                                ProCon(text: "Pure Android", type: .pro)
                            ],
                            cons: []
                        )
                    ]
                )
            )
            .environmentObject(DatabaseService.shared)
        }
    }
}
