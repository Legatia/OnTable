import SwiftUI

struct HomeView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @ObservedObject var premiumManager = PremiumManager.shared

    @State private var navigateToDecision: Decision?
    @State private var isNavigating = false
    @State private var showingSettings = false
    @State private var showingTemplates = false
    @State private var showingPaywall = false
    @State private var showingHistory = false
    @State private var sharingDecision: Decision?
    @State private var showingJoinRoom = false
    @State private var showingRoom = false
    @State private var decisionToJoin: Decision?
    @ObservedObject private var roomService = RoomService.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // New Decision Buttons
                HStack(spacing: 12) {
                    // Blank Decision
                    Button(action: createNewDecision) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Blank")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // Templates (Premium)
                    Button(action: openTemplates) {
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "doc.text.fill")
                                    .font(.title2)
                                if !premiumManager.features.hasTemplates {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .offset(x: 8, y: -4)
                                }
                            }
                            Text("Templates")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(premiumManager.features.hasTemplates ? Color.purple : Color(.systemGray4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // Join Room (Any user)
                    Button(action: { showingJoinRoom = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.title2)
                            Text("Join")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()

                // History List
                if databaseService.decisions.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "scale.3d")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No decisions yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap above to weigh your first choice")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(databaseService.decisions) { decision in
                            HStack {
                                NavigationLink(destination: DecisionView(decision: decision).environmentObject(databaseService)) {
                                    DecisionRow(decision: decision) {
                                        if premiumManager.features.canShare {
                                            sharingDecision = decision
                                        } else {
                                            showingPaywall = true
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteDecisions)
                    }
                    .listStyle(.plain)
                }

                // Hidden NavigationLink for programmatic navigation
                NavigationLink(
                    destination: Group {
                        if let decision = navigateToDecision {
                            DecisionView(decision: decision)
                                .environmentObject(databaseService)
                        }
                    },
                    isActive: $isNavigating
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationTitle("OnTable")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingHistory = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("History")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: tierIcon)
                                .font(.caption)
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingTemplates) {
                TemplatesView()
                    .environmentObject(databaseService)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingHistory) {
                DecisionHistoryView()
                    .environmentObject(databaseService)
            }
            .sheet(item: $sharingDecision) { decision in
                ShareSheetView(decision: decision)
            }
            .sheet(isPresented: $showingJoinRoom) {
                QRScannerView()
            }
            .fullScreenCover(isPresented: $showingRoom) {
                if let decision = decisionToJoin {
                    NavigationView {
                        RoomView(decision: Binding(
                            get: { decision },
                            set: { decisionToJoin = $0 }
                        ), isHost: false)
                        .environmentObject(databaseService)
                    }
                }
            }
            .onChange(of: roomService.isJoined) { isJoined in
                if isJoined {
                    // Wait for the room data to arrive via messages
                    showingJoinRoom = false
                    // RoomView will be shown once currentRoom is non-nil
                }
            }
            .onChange(of: roomService.currentRoom) { room in
                if roomService.isJoined, let room = room {
                    decisionToJoin = room.decision
                    showingRoom = true
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func openTemplates() {
        if premiumManager.features.hasTemplates {
            showingTemplates = true
        } else {
            showingPaywall = true
        }
    }

    private var tierIcon: String {
        switch premiumManager.currentTier {
        case .free: return "person"
        case .starter: return "star.fill"
        case .premium: return "crown.fill"
        }
    }

    private func createNewDecision() {
        let newDecision = databaseService.createNewDecision()
        navigateToDecision = newDecision
        isNavigating = true
    }

    private func deleteDecisions(at offsets: IndexSet) {
        for index in offsets {
            let decision = databaseService.decisions[index]
            databaseService.deleteDecision(decision)
        }
    }
}

// MARK: - Decision Row

struct DecisionRow: View {
    let decision: Decision
    let onShare: () -> Void
    @ObservedObject var premiumManager = PremiumManager.shared

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(decision.isResolved ? Color.green : Color.orange)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                // Title or options
                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                // Date and status
                HStack {
                    Text(dateFormatter.string(from: decision.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if decision.isResolved, let winner = decision.winningOption {
                        Text("Chose: \(winner.title)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if decision.isCollaborative {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Outcome badge if tracked
                if let outcome = decision.outcome {
                    OutcomeBadge(outcome: outcome)
                }
            }

            Spacer()

            // Quick share button
            Button(action: onShare) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(premiumManager.features.canShare ? .accentColor : .secondary)
                    
                    if !premiumManager.features.canShare {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .padding(2)
                            .background(Color.white)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
                .padding(8)
                .background(premiumManager.features.canShare ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                .clipShape(Circle())
            }
            .buttonStyle(.plain) // Ensure it doesn't trigger the whole row

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var displayTitle: String {
        decision.displayTitle
    }
}

// MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(DatabaseService.shared)
    }
}
