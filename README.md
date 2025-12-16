# Mooder (MVP / v1)

Mooder is a lightweight mood check-in app designed to help users reflect on how they’re feeling, recognize patterns over time, and receive small, practical suggestions tailored to their current state.

This repository contains the MVP / v1 implementation, focused on validating core UX, data flow, and AI-assisted suggestions.

---

## What Mooder Does

Mooder lets users:
- Log mood check-ins by selecting a primary mood
- Rate energy, focus, connection, and physical tension on a 0–10 scale
- Optionally select up to three drivers (e.g. work, stress, relationships)
- Receive AI-generated suggestions based on their check-in
- View, edit, and delete past check-ins
- Explore insights and trends over time

Safety is built in: when sensitive states are detected, suggestions are limited or disabled.

---

## Core Features

### Mood Check-ins
- Primary mood selection
- Quantitative sliders (energy, focus, connection, tension)
- Optional drivers
- Safety check handling

### Suggestions
- Category-based suggestions (quick actions, activities, meditation, food, books)
- Suggestions are generated per check-in
- Saved and reusable from history
- Users can generate suggestions later for categories they didn’t initially choose
- Automatic fallback to a secondary AI provider when quota limits are reached

### History
- Chronological list of check-ins
- Emoji-enhanced mood display
- View full check-in details
- Generate or regenerate suggestions from past check-ins

### Insights
- Summary statistics over the last 7 or 30 days
- Single, interpretable overall mood score (0–10) trend line
- Clear explanation of how the overall score is calculated
- Most common moods with percentages
- Top drivers with accurate percentage breakdowns

---

## Design Principles
- Calm, supportive, non-judgmental language
- No diagnosis or medical advice
- Emphasis on small, achievable actions
- Privacy-first data handling
- Safety-aware UX
- Trends over time are emphasized over “perfect” scores

---

## Tech Stack

### Frontend
- Flutter (Material 3)
- Firebase Authentication
- Cloud Firestore
- fl_chart (insights and trends)

### Backend
- Node.js + Express
- Firebase Admin SDK
- Google Gemini API (primary AI provider)
- Cloudflare Workers AI (fallback)

### Hosting
- Render (backend API hosting with HTTPS)
- Firebase (auth + database)

---

## Environment Variables

Sensitive files are never committed.

Create a .env file locally using .env.example as a reference.

Required variables:
- GEMINI_API_KEY
- GEMINI_MODEL
- FIREBASE_SERVICE_ACCOUNT_PATH
- CLOUDFLARE_ACCOUNT_ID
- CLOUDFLARE_API_TOKEN

---

## Running the Project

### Backend
cd server  
npm install  
npm start  

Health check: GET /health

### Flutter App
flutter pub get  
flutter run  

For local development, the backend URL can be overridden using:
flutter run --dart-define=BACKEND_BASE_URL=http://<your-ip>:8787

Production builds use the deployed backend automatically.

---

## Disclaimer

Mooder is a self-reflection and wellbeing support tool.  
It does not provide medical or mental health diagnosis or treatment.

If you are in immediate danger or distress, contact local emergency services or a trusted person.

---

## Author

Built by Mike Lim as an MVP to explore product design, UX, and AI-assisted self-reflection.
