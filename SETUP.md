# OnTable - iOS App Setup

A lightweight decision-making app with split-screen comparison and nearby collaboration.

## Quick Start

### 1. Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select "App" under iOS
4. Configure:
   - **Product Name:** OnTable
   - **Organization Identifier:** your.identifier
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None (we're using SQLite)
5. Save to the `OnTable` folder (replace the auto-generated `OnTable` subfolder)

### 2. Add SQLite.swift Dependency

1. In Xcode, go to File → Add Package Dependencies
2. Enter URL: `https://github.com/stephencelis/SQLite.swift.git`
3. Set version rule: "Up to Next Major" from `0.14.0`
4. Click Add Package
5. Select "SQLite" and add to OnTable target

### 3. Add Required Permissions (Info.plist)

Add these keys to your Info.plist for camera and local networking:

```xml
<!-- Camera for QR scanning -->
<key>NSCameraUsageDescription</key>
<string>Camera access is needed to scan QR codes and join collaboration rooms.</string>

<!-- Local Network for MultipeerConnectivity -->
<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is needed to collaborate with nearby friends.</string>

<!-- Bonjour Services -->
<key>NSBonjourServices</key>
<array>
    <string>_ontable-room._tcp</string>
    <string>_ontable-room._udp</string>
</array>
```

### 4. Add Source Files

The source files are already in the `OnTable/` subfolder:

```
OnTable/
├── OnTableApp.swift
├── Models/
│   ├── Decision.swift
│   └── Database.swift
├── Views/
│   ├── HomeView.swift
│   ├── DecisionView.swift
│   ├── OptionCard.swift
│   ├── ProConRow.swift
│   ├── ResolutionView.swift
│   ├── ShareCardView.swift
│   ├── ShareSheetView.swift
│   ├── RoomView.swift
│   ├── QRDisplayView.swift
│   └── QRScannerView.swift
└── Services/
    ├── DatabaseService.swift
    ├── ShareService.swift
    ├── RoomService.swift
    └── PremiumManager.swift
```

In Xcode:
1. Delete the auto-generated `ContentView.swift`
2. Right-click on the OnTable folder in Project Navigator
3. Add Files to "OnTable"
4. Select all folders (Models, Views, Services) and files
5. Ensure "Copy items if needed" is unchecked
6. Ensure "Create groups" is selected
7. Click Add

### 5. Build & Run

1. Select an iOS Simulator (iPhone 14 or newer recommended)
2. Press Cmd+R to build and run

**Note:** QR scanning and MultipeerConnectivity require a real device for full testing.

---

## Features Implemented

### Phase 1: Core Solo Experience
- [x] Create new decisions
- [x] Split-screen comparison view
- [x] Add/delete pros and cons
- [x] Weight system (tap to cycle: normal → bold → huge)
- [x] Score calculation
- [x] Resolution flow with "gut check"
- [x] Decision history with SQLite persistence
- [x] Swipe to delete decisions

### Phase 2: Social Sharing
- [x] Share as 1:1 social card (Instagram/Twitter/Facebook ready)
- [x] Multiple card templates (Classic, Minimal, Bold)
- [x] Premium templates (Neon, Paper) - locked for free users
- [x] Watermark on free tier, removable for premium

### Phase 3: Collaboration
- [x] Host a room with QR code
- [x] Join room via QR scan or manual code
- [x] Real-time sync via MultipeerConnectivity
- [x] Participant list with vote tracking
- [x] Works offline - no server needed

---

## URL Scheme

The app registers the `ontable://` URL scheme for deep linking:

```
ontable://join?code=ABC123&host=DeviceName
```

To set this up:
1. Go to Project → Target → Info → URL Types
2. Add new URL Type:
   - Identifier: `com.yourcompany.ontable`
   - URL Schemes: `ontable`
   - Role: Editor

---

## Minimum Requirements

- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

---

## Testing Collaboration

MultipeerConnectivity requires two physical devices on the same network:

1. Run app on Device A
2. Create a decision, tap menu → "Host Room"
3. Run app on Device B
4. Tap menu → "Join Room"
5. Scan the QR code on Device A
6. Both devices should now be in sync

**Simulator limitation:** MultipeerConnectivity doesn't work between simulators. Use physical devices for testing collaboration features.
