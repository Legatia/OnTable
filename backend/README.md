# OnTable AI Proxy Server

Backend proxy server for OnTable app's AI features. Keeps your Gemini API key secure on the server instead of embedded in the app.

## Setup

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Set Your API Key

Create a `.env` file from the example:

```bash
cp .env.example .env
```

Then edit `.env` and add your Gemini API key:

```bash
GEMINI_API_KEY=AIzaSyC_YourActualKeyHere...
```

Get your free API key at: https://aistudio.google.com/apikey

**Important:** The `.env` file is already in `.gitignore` and will never be committed to git.

### 3. Run the Server

**Development (auto-restart on changes):**
```bash
npm run dev
```

**Production:**
```bash
npm start
```

The server will run on `http://localhost:3000`

## Endpoints

### Health Check
```
GET /health
```

Returns server status.

### AI Suggestions
```
POST /api/ai/suggestions
Content-Type: application/json

{
  "prompt": "Your decision analysis prompt here..."
}
```

Returns AI-generated suggestions.

## iOS App Configuration

The iOS app is already configured to use this backend. Make sure:

1. Server is running on `http://localhost:3000`
2. For device testing, update `AIService.swift` to use your Mac's local IP (e.g., `http://192.168.1.100:3000`)

## Deployment to Vercel

### 1. Install Vercel CLI (if you haven't)

```bash
npm install -g vercel
```

### 2. Deploy from the backend directory

```bash
cd backend
vercel
```

Follow the prompts:
- **Set up and deploy?** Yes
- **Which scope?** Your account
- **Link to existing project?** No
- **Project name?** ontable-ai-proxy (or your choice)
- **Directory?** ./ (current directory)
- **Override settings?** No

### 3. Set Environment Variable in Vercel

**IMPORTANT:** After deployment, you must add your API key to Vercel:

```bash
vercel env add GEMINI_API_KEY
```

When prompted:
- **Value:** Paste your Gemini API key
- **Environment:** Production, Preview, Development (select all)

Or set it in the Vercel Dashboard:
1. Go to your project settings
2. Navigate to "Environment Variables"
3. Add `GEMINI_API_KEY` with your API key value

### 4. Redeploy to apply environment variables

```bash
vercel --prod
```

### 5. Update iOS App

Copy your Vercel URL (e.g., `https://ontable-ai-proxy.vercel.app`) and update `AIService.swift`:

```swift
private let backendURL = "https://your-project.vercel.app/api/ai/suggestions"
```

### Alternative Deployment Options

- **Heroku**: `heroku create && git push heroku main`
- **Railway**: Connect GitHub repo
- **Render**: Connect GitHub repo

## Security Notes

- ✅ API key stays on server, never in app binary
- ✅ CORS enabled (restrict domains in production)
- ⚠️ Add rate limiting for production
- ⚠️ Add authentication for production (API keys, JWT, etc.)
