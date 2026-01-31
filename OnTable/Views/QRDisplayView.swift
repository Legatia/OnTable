import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRDisplayView: View {
    @ObservedObject var roomService = RoomService.shared
    @Environment(\.dismiss) private var dismiss

    let decision: Decision

    @State private var qrImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Room code
                if let code = roomService.roomCode {
                    VStack(spacing: 4) {
                        Text("Room Code")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(code)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .tracking(4)
                    }
                }

                // QR Code
                if let qrImage = qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                } else {
                    ProgressView()
                        .frame(width: 200, height: 200)
                }

                Text("Scan to join this decision")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Connected participants
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("Participants (\(roomService.connectedPeers.count + 1))")
                            .font(.headline)
                    }

                    // Host (you)
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(UIDevice.current.name)
                            .font(.subheadline)
                        Text("(Host)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    // Connected peers
                    ForEach(roomService.connectedPeers, id: \.displayName) { peer in
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text(peer.displayName)
                                .font(.subheadline)
                            Spacer()
                        }
                    }

                    if roomService.connectedPeers.isEmpty {
                        Text("Waiting for others to join...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()

                // Start collaborating button
                if !roomService.connectedPeers.isEmpty {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Collaborating")
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
            .padding()
            .navigationTitle("Invite Others")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        roomService.stopHosting()
                        dismiss()
                    }
                }
            }
            .onAppear {
                startHosting()
            }
            .onDisappear {
                // Keep hosting if we're going to collaborate
                // Only stop if actually cancelled
            }
        }
    }

    private func startHosting() {
        roomService.hostRoom(with: decision)
        generateQRCode()
    }

    private func generateQRCode() {
        guard let data = roomService.qrCodeData() else { return }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(data.utf8)
        filter.correctionLevel = "M"

        if let outputImage = filter.outputImage {
            // Scale up the QR code
            let scale = 10.0
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrImage = UIImage(cgImage: cgImage)
            }
        }
    }
}

// MARK: - Preview

struct QRDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        QRDisplayView(
            decision: Decision(
                title: "Test Decision",
                options: [
                    Option(title: "Option A"),
                    Option(title: "Option B")
                ]
            )
        )
    }
}
