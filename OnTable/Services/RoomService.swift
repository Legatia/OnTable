import Foundation
import MultipeerConnectivity
import Combine

// MARK: - Room Message

enum RoomMessage: Codable {
    case decisionUpdate(Decision)
    case participantJoined(Participant)
    case participantLeft(String) // participant ID
    case vote(participantId: String, optionId: UUID)
    case roomClosed
}

// MARK: - Room Service

class RoomService: NSObject, ObservableObject {
    // Singleton for easy access
    static let shared = RoomService()

    // Published state
    @Published var isHosting = false
    @Published var isJoined = false
    @Published var currentRoom: Room?
    @Published var connectedPeers: [MCPeerID] = []
    @Published var error: String?

    // MultipeerConnectivity
    private let serviceType = "ontable-room"
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // Room info for QR
    var roomCode: String?

    private override init() {
        super.init()
        setupPeerID()
    }

    private func setupPeerID() {
        let displayName = UIDevice.current.name
        peerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    // MARK: - Host a Room

    func hostRoom(with decision: Decision) {
        // Generate room code
        roomCode = generateRoomCode()

        // Create room
        let room = Room(
            hostName: peerID.displayName,
            participants: [],
            decision: decision
        )
        currentRoom = room

        // Start advertising
        let discoveryInfo = ["roomCode": roomCode!]
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        isHosting = true
        error = nil
    }

    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil

        // Notify all peers
        sendMessage(.roomClosed)

        session.disconnect()
        isHosting = false
        currentRoom = nil
        roomCode = nil
        connectedPeers = []
    }

    // MARK: - Join a Room

    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    func joinRoom(peerID: MCPeerID) {
        browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func leaveRoom() {
        session.disconnect()
        isJoined = false
        currentRoom = nil
        connectedPeers = []
    }

    // MARK: - Send Updates

    func sendDecisionUpdate(_ decision: Decision) {
        currentRoom?.decision = decision
        sendMessage(.decisionUpdate(decision))
    }

    func sendVote(optionId: UUID) {
        let participantId = peerID.displayName
        sendMessage(.vote(participantId: participantId, optionId: optionId))
    }

    private func sendMessage(_ message: RoomMessage) {
        guard !session.connectedPeers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Error sending message: \(error)")
        }
    }

    // MARK: - Helpers

    private func generateRoomCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }

    func qrCodeData() -> String? {
        guard let roomCode = roomCode else { return nil }
        // Format: ontable://join?code=ABCD12&host=DeviceName
        let hostEncoded = peerID.displayName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "ontable://join?code=\(roomCode)&host=\(hostEncoded)"
    }
}

// MARK: - MCSessionDelegate

extension RoomService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectedPeers = session.connectedPeers

                if self.isHosting {
                    // Send current decision to new peer
                    if let room = self.currentRoom {
                        let participant = Participant(name: peerID.displayName)
                        self.currentRoom?.participants.append(participant)
                        self.sendMessage(.participantJoined(participant))
                        self.sendMessage(.decisionUpdate(room.decision))
                    }
                } else {
                    self.isJoined = true
                }

            case .notConnected:
                self.connectedPeers = session.connectedPeers

                if !self.isHosting {
                    // We got disconnected
                    if session.connectedPeers.isEmpty {
                        self.isJoined = false
                        self.currentRoom = nil
                    }
                } else {
                    // Remove participant
                    self.currentRoom?.participants.removeAll { $0.name == peerID.displayName }
                    self.sendMessage(.participantLeft(peerID.displayName))
                }

            case .connecting:
                break

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(RoomMessage.self, from: data)

            DispatchQueue.main.async {
                self.handleMessage(message, from: peerID)
            }
        } catch {
            print("Error decoding message: \(error)")
        }
    }

    private func handleMessage(_ message: RoomMessage, from peerID: MCPeerID) {
        switch message {
        case .decisionUpdate(let decision):
            if currentRoom == nil {
                currentRoom = Room(hostName: peerID.displayName, decision: decision)
            } else {
                currentRoom?.decision = decision
            }

        case .participantJoined(let participant):
            if currentRoom == nil {
                // Should not happen as host sends decision first, but for safety:
                currentRoom = Room(hostName: "Host", decision: Decision())
            }
            if currentRoom?.participants.contains(where: { $0.id == participant.id }) == false {
                currentRoom?.participants.append(participant)
            }

        case .participantLeft(let participantId):
            currentRoom?.participants.removeAll { $0.name == participantId }

        case .vote(let participantId, let optionId):
            if let index = currentRoom?.participants.firstIndex(where: { $0.name == participantId }) {
                currentRoom?.participants[index].votedForOptionId = optionId
            }

        case .roomClosed:
            leaveRoom()
            error = "Room was closed by host"
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension RoomService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations when hosting
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.error = "Failed to start room: \(error.localizedDescription)"
            self.isHosting = false
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension RoomService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Check if this is the room we're looking for
        if let targetCode = roomCode, let peerCode = info?["roomCode"], peerCode == targetCode {
            joinRoom(peerID: peerID)
            stopBrowsing()
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.error = "Failed to search for rooms: \(error.localizedDescription)"
        }
    }
}
