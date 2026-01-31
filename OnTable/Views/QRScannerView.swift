import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @ObservedObject var roomService = RoomService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isScanning = true
    @State private var scannedCode: String?
    @State private var showManualEntry = false
    @State private var manualCode = ""
    @State private var cameraPermissionDenied = false

    var body: some View {
        NavigationView {
            ZStack {
                if cameraPermissionDenied {
                    cameraPermissionView
                } else {
                    // Camera preview
                    CameraPreviewView(
                        isScanning: $isScanning,
                        onCodeScanned: handleScannedCode
                    )
                    .ignoresSafeArea()

                    // Overlay
                    VStack {
                        Spacer()

                        // Scan frame
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 250, height: 250)
                            .background(Color.black.opacity(0.001)) // For hit testing

                        Spacer()

                        // Bottom panel
                        VStack(spacing: 16) {
                            if let code = scannedCode {
                                // Found code
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Found: \(code)")
                                        .font(.headline)
                                }

                                if roomService.isJoined {
                                    Text("Connected!")
                                        .foregroundColor(.green)
                                } else {
                                    ProgressView("Connecting...")
                                }
                            } else {
                                Text("Point camera at QR code")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }

                            // Manual entry button
                            Button(action: { showManualEntry = true }) {
                                Text("Enter code manually")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle("Join Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        roomService.stopBrowsing()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                manualEntrySheet
            }
            .onAppear {
                checkCameraPermission()
            }
            .onChange(of: roomService.isJoined) { isJoined in
                if isJoined {
                    // Successfully joined, dismiss after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Camera Permission View

    private var cameraPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Camera Access Required")
                .font(.headline)

            Text("To scan QR codes, please allow camera access in Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Enter Code Manually") {
                showManualEntry = true
            }
            .foregroundColor(.accentColor)
        }
        .padding()
    }

    // MARK: - Manual Entry Sheet

    private var manualEntrySheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Enter the 6-digit room code")
                    .font(.headline)

                TextField("XXXXXX", text: $manualCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: manualCode) { newValue in
                        // Limit to 6 characters, uppercase only
                        let filtered = String(newValue.uppercased().prefix(6))
                        if filtered != newValue {
                            manualCode = filtered
                        }
                    }

                Button(action: joinWithManualCode) {
                    Text("Join Room")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(manualCode.count == 6 ? Color.accentColor : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(manualCode.count != 6)

                Spacer()
            }
            .padding()
            .navigationTitle("Enter Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showManualEntry = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionDenied = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionDenied = !granted
                }
            }
        case .denied, .restricted:
            cameraPermissionDenied = true
        @unknown default:
            cameraPermissionDenied = true
        }
    }

    private func handleScannedCode(_ code: String) {
        guard scannedCode == nil else { return } // Only process once

        // Parse QR code: ontable://join?code=ABCD12&host=DeviceName
        if let url = URL(string: code),
           url.scheme == "ontable",
           url.host == "join",
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let codeParam = components.queryItems?.first(where: { $0.name == "code" })?.value {

            scannedCode = codeParam
            isScanning = false
            joinRoom(code: codeParam)
        }
    }

    private func joinWithManualCode() {
        showManualEntry = false
        scannedCode = manualCode
        joinRoom(code: manualCode)
    }

    private func joinRoom(code: String) {
        roomService.roomCode = code
        roomService.startBrowsing()
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    @Binding var isScanning: Bool
    let onCodeScanned: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let captureSession = AVCaptureSession()
        context.coordinator.captureSession = captureSession

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            return view
        }

        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds

        if isScanning {
            if context.coordinator.captureSession?.isRunning == false {
                DispatchQueue.global(qos: .userInitiated).async {
                    context.coordinator.captureSession?.startRunning()
                }
            }
        } else {
            if context.coordinator.captureSession?.isRunning == true {
                context.coordinator.captureSession?.stopRunning()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        let onCodeScanned: (String) -> Void

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               metadataObject.type == .qr,
               let stringValue = metadataObject.stringValue {
                onCodeScanned(stringValue)
            }
        }
    }
}

// MARK: - Preview

struct QRScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRScannerView()
    }
}
