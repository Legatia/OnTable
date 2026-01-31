require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.PORT || 3000;

// Load config
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const CLIENT_API_KEY = process.env.CLIENT_API_KEY;

// Security Middleware
app.use(helmet());

// Rate Limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// AI Endpoint Limiter (Stricter)
const aiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20, // 20 AI requests per 15 minutes
  message: { error: 'Too many AI requests, please try again later.' }
});

// Middleware
app.use(cors({
  origin: process.env.NODE_ENV === 'production' ? false : '*', // Restrict in production
  methods: ['GET', 'POST']
}));
app.use(express.json());

// API Key Authentication Middleware
const authenticateClient = (req, res, next) => {
  const clientKey = req.headers['x-client-api-key'];

  // Skip auth for health check or if not configured (dev mode fallback)
  if (req.path === '/health') return next();

  if (!CLIENT_API_KEY) {
    console.warn('⚠️ CLIENT_API_KEY not set in environment - allowing request (DEV MODE)');
    return next();
  }

  if (!clientKey || clientKey !== CLIENT_API_KEY) {
    return res.status(401).json({ error: 'Unauthorized: Invalid Client API Key' });
  }

  next();
};

app.use(authenticateClient);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'OnTable AI Proxy', secure: true });
});

// Root route
app.get('/', (req, res) => {
  res.send('OnTable AI Proxy is running. Go to /health for status.');
});

// AI suggestions endpoint
app.post('/api/ai/suggestions', aiLimiter, async (req, res) => {
  try {
    // Validate API key is set
    if (!GEMINI_API_KEY) {
      return res.status(500).json({
        error: 'Server configuration error: GEMINI_API_KEY not set in .env file'
      });
    }

    // Get prompt from request
    const { prompt } = req.body;

    if (!prompt) {
      return res.status(400).json({ error: 'Prompt is required' });
    }

    // Call Gemini API
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${GEMINI_API_KEY}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contents: [{
          parts: [{ text: prompt }]
        }],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 1024
        }
      })
    });

    if (!geminiResponse.ok) {
      const errorData = await geminiResponse.text();
      console.error('Gemini API error:', errorData);
      return res.status(geminiResponse.status).json({
        error: 'AI service error',
        details: errorData
      });
    }

    const data = await geminiResponse.json();

    // Extract text from Gemini response
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      return res.status(500).json({
        error: 'Invalid response from AI service'
      });
    }

    // Return the text response
    res.json({ text });

  } catch (error) {
    console.error('Error processing AI request:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// Only start server if running locally (not on Vercel)
if (process.env.NODE_ENV !== 'production') {
  app.listen(PORT, () => {
    console.log(`🚀 OnTable AI Proxy running on port ${PORT}`);
    console.log(`📍 Health check: http://localhost:${PORT}/health`);
    console.log(`🤖 AI endpoint: http://localhost:${PORT}/api/ai/suggestions`);
    console.log(`🔒 Security: Helmet enabled, Rate Limiting active`);
    console.log(CLIENT_API_KEY ? `🔑 Basic Auth: Enabled` : `⚠️ Basic Auth: DISABLED (Set CLIENT_API_KEY)`);

    if (!GEMINI_API_KEY) {
      console.warn('⚠️  WARNING: GEMINI_API_KEY not found in .env file!');
      console.warn('   Create a .env file with: GEMINI_API_KEY=your_key_here');
    } else {
      console.log('✅ Gemini API key configured');
    }
  });
}

// Export for Vercel
module.exports = app;
