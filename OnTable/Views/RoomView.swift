import SwiftUI

struct RoomView: View {
    @ObservedObject var roomService = RoomService.shared
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) private var dismiss

    @Binding var decision: Decision
    let isHost: Bool

    @State private var showingQRDisplay = false
    @State private var showingEndConfirmation = false
    @State private var currentPage = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Participants bar
                participantsBar
                    .padding()
                    .background(Color(.systemGray6))

                // Decision view (simplified for collab)
                GeometryReader { geometry in
                    collaborativeDecisionView(geometry: geometry)
                }

                // Bottom actions
                bottomBar
            }
            .navigationTitle(isHost ? "Your Room" : "Collaborating")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(isHost ? "End Room" : "Leave") {
                    if isHost {
                        showingEndConfirmation = true
                    } else {
                        leaveRoom()
                    }
                },
                trailing: isHost ? Button(action: { showingQRDisplay = true }) {
                    Image(systemName: "qrcode")
                } : nil
            )
            .sheet(isPresented: $showingQRDisplay) {
                QRDisplayView(decision: decision)
            }
            .alert("End Room?", isPresented: $showingEndConfirmation) {
                Button("End Room", role: .destructive) {
                    endRoom()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will disconnect all participants.")
            }
            .onChange(of: roomService.currentRoom?.decision) { newDecision in
                if let newDecision = newDecision {
                    decision = newDecision
                }
            }
            .onChange(of: decision) { newDecision in
                if isHost {
                    roomService.sendDecisionUpdate(newDecision)
                }
            }
            .onReceive(roomService.$isJoined) { isJoined in
                if !isHost && !isJoined && roomService.currentRoom == nil {
                    // Got disconnected
                    dismiss()
                }
            }
        }
    }

    // MARK: - Participants Bar

    private var participantsBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.accentColor)
                Text("Participants")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if let code = roomService.roomCode, isHost {
                    Text("Code: \(code)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Host
                    participantBubble(
                        name: isHost ? "You" : (roomService.currentRoom?.hostName ?? "Host"),
                        isHost: true,
                        votedForOptionId: nil
                    )

                    // Other participants
                    if let participants = roomService.currentRoom?.participants {
                        ForEach(participants) { participant in
                            participantBubble(
                                name: participant.name,
                                isHost: false,
                                votedForOptionId: participant.votedForOptionId
                            )
                        }
                    }

                    // Connected peers (for non-host view)
                    if !isHost {
                        ForEach(roomService.connectedPeers.dropFirst(), id: \.displayName) { peer in
                            participantBubble(
                                name: peer.displayName,
                                isHost: false,
                                votedForOptionId: nil
                            )
                        }
                    }
                }
            }
        }
    }

    private func participantBubble(name: String, isHost: Bool, votedForOptionId: UUID?) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isHost ? Color.accentColor : Color(.systemGray4))
                    .frame(width: 40, height: 40)

                Text(String(name.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(isHost ? .white : .primary)

                // Vote indicator
                if let votedId = votedForOptionId,
                   let index = decision.options.firstIndex(where: { $0.id == votedId }) {
                    let colors: [Color] = [.blue, .orange, .purple, .green, .pink]
                    Circle()
                        .fill(colors[index % colors.count])
                        .frame(width: 12, height: 12)
                        .offset(x: 14, y: 14)
                }
            }

            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 50)
    }

    // MARK: - Collaborative Decision View

    @ViewBuilder
    private func collaborativeDecisionView(geometry: GeometryProxy) -> some View {
        let isLandscape = geometry.size.width > geometry.size.height

        if isLandscape {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(decision.options.indices, id: \.self) { index in
                        collaborativeOptionCard(index: index)
                            .frame(width: max(100, (geometry.size.width - 36) / 2))
                    }
                }
                .padding()
            }
        } else {
            TabView(selection: $currentPage) {
                ForEach(decision.options.indices, id: \.self) { index in
                    collaborativeOptionCard(index: index)
                        .padding()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
    }

    private func collaborativeOptionCard(index: Int) -> some View {
        let option = decision.options[index]

        return VStack(alignment: .leading, spacing: 12) {
            // Title
            if isHost {
                TextField("Option \(decision.optionLabel(at: index))", text: $decision.options[index].title)
                    .font(Font.title3.weight(.semibold))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Text(option.title.isEmpty ? "Option \(decision.optionLabel(at: index))" : option.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            // Score
            HStack {
                Spacer()
                Text("Score: \(option.score)")
                    .font(.headline)
                    .foregroundColor(option.score > 0 ? .green : (option.score < 0 ? .red : .secondary))
            }

            // Pros
            VStack(alignment: .leading, spacing: 6) {
                Label("Pros", systemImage: "hand.thumbsup.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)

                ForEach(option.pros) { pro in
                    HStack {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(pro.text)
                            .font(.subheadline)
                        if pro.addedBy != "me" {
                            Text("— \(pro.addedBy)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Cons
            VStack(alignment: .leading, spacing: 6) {
                Label("Cons", systemImage: "hand.thumbsdown.fill")
                    .font(.subheadline)
                    .foregroundColor(.red)

                ForEach(option.cons) { con in
                    HStack {
                        Circle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(con.text)
                            .font(.subheadline)
                        if con.addedBy != "me" {
                            Text("— \(con.addedBy)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Quick vote button
            let colors: [Color] = [.blue, .orange, .purple, .green, .pink]
            Button(action: { vote(for: index) }) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("Vote for this")
                }
                .font(Font.subheadline.weight(.medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(colors[index % colors.count])
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Vote tally
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(decision.options.indices, id: \.self) { index in
                        if index > 0 {
                            Text("vs")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        voteTally(index: index)
                    }
                }
            }

            Spacer()

            if isHost {
                Button("Finalize") {
                    // Go to resolution
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func voteTally(index: Int) -> some View {
        let count = roomService.currentRoom?.participants.filter { $0.votedForOptionId == decision.options[index].id }.count ?? 0
        let colors: [Color] = [.blue, .orange, .purple, .green, .pink]

        return VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colors[index % colors.count])
            Text("votes")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func vote(for index: Int) {
        guard index < decision.options.count else { return }
        roomService.sendVote(optionId: decision.options[index].id)
    }

    private func leaveRoom() {
        roomService.leaveRoom()
        dismiss()
    }

    private func endRoom() {
        // Save final decision
        databaseService.saveDecision(decision)
        roomService.stopHosting()
        dismiss()
    }
}

// MARK: - Preview

struct RoomView_Previews: PreviewProvider {
    static var previews: some View {
        RoomView(
            decision: .constant(Decision(
                title: "Dinner",
                options: [
                    Option(title: "Pizza", pros: [ProCon(text: "Tasty", type: .pro)]),
                    Option(title: "Salad", pros: [ProCon(text: "Healthy", type: .pro)]),
                    Option(title: "Sushi", pros: [ProCon(text: "Fresh", type: .pro)])
                ]
            )),
            isHost: true
        )
        .environmentObject(DatabaseService.shared)
    }
}
