require('dotenv').config();
const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
const PORT = process.env.PORT || 3000;

// Load API key from environment variable
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'OnTable AI Proxy' });
});

// AI suggestions endpoint
app.post('/api/ai/suggestions', async (req, res) => {
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
