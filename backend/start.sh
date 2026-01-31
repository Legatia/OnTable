#!/bin/bash

# OnTable Backend Quick Start Script

echo "🚀 Starting OnTable AI Proxy Server..."
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  WARNING: .env file not found!"
    echo "Please create a .env file with your Gemini API key:"
    echo ""
    echo "  cp .env.example .env"
    echo "  # Then edit .env and add your key"
    echo ""
    echo "Get your free key at: https://aistudio.google.com/apikey"
    echo ""
    read -p "Press Enter to continue anyway (server will not work) or Ctrl+C to exit..."
fi

# Start the server
echo "🎯 Starting server on http://localhost:3000"
npm start
