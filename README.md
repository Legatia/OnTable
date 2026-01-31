# OnTable

**Decision-making with AI insights.**

OnTable helps you make better decisions by weighing pros and cons, collaborating with friends, and getting AI-powered suggestions.

## Project Structure

- **`OnTable/`**: The iOS application (SwiftUI).
- **`backend/`**: The AI proxy server (Node.js/Express).

## Getting Started

### iOS App

The iOS app is built with SwiftUI and uses SQLite for local storage.

👉 **[Read the iOS Setup Guide](SETUP.md)**

### Backend Server

The backend acts as a secure proxy for the Google Gemini API, keeping your API keys safe.

👉 **[Read the Backend Setup Guide](backend/README.md)**

## Features

- **Split-Screen Comparison**: Visualise two options side-by-side.
- **AI Suggestions**: Get impartial advice from Google Gemini (via the backend).
- **Collaboration**: Host rooms and vote with friends nearby (P2P).
- **Templates**: Share your decisions with beautiful social cards.

## Requirements

- **iOS**: Xcode 15.0+, iOS 15.0+
- **Backend**: Node.js 18+
