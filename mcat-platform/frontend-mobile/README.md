# MCAT Platform - Production Mobile App 🌙

**Complete, production-ready dark-themed mobile web app** for MCAT test prep.

## ✨ Features

- 🌙 **Beautiful Dark Theme** - Optimized for low-light studying
- 🔐 **Secure Authentication** - JWT-based login/register
- 📊 **Real-time Dashboard** - Live performance metrics
- 🎯 **Intelligent Question Bank** - Browse, filter, practice
- 📈 **Progress Tracking** - Detailed analytics and insights
- 🧠 **AI Reasoning Analysis** - Detect 5+ behavioral patterns
- 🎓 **Adaptive Overlays** - Tier-based feedback (free/pro/premium)
- 📱 **Mobile-First PWA** - Install on any device
- ⚡ **Lightning Fast** - Next.js 14 with automatic optimization

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Start development server (port 3001)
npm run dev

# Build for production
npm run build
npm start
```

Open **http://localhost:3001**

## 🎨 Dark Theme

Carefully designed color palette for optimal readability:

```
Background:  #0f172a  (slate-900)
Card:        #1e293b  (slate-800)
Border:      #334155  (slate-700)
Text:        #f1f5f9  (slate-100)
Muted:       #94a3b8  (slate-400)

Primary:     #3b82f6  (blue-500)
Success:     #10b981  (emerald-500)
Danger:      #ef4444  (red-500)
Warning:     #f59e0b  (amber-500)
```

## 📦 Tech Stack

- **Framework**: Next.js 14
- **Language**: JavaScript (TypeScript ready)
- **Styling**: TailwindCSS 3.3
- **State**: Zustand (lightweight, fast)
- **API**: Axios with interceptors
- **UI**: Framer Motion, React Hot Toast
- **Charts**: Recharts (planned)

## 📱 App Structure

```
frontend-mobile/
├── pages/
│   ├── _app.js          # App wrapper
│   ├── _document.js     # HTML document
│   └── index.js         # Main app (all-in-one demo)
├── lib/
│   ├── api.js           # API client with auth
│   └── store.js         # Zustand state management
├── styles/
│   └── globals.css      # Dark theme styles
├── public/
│   └── manifest.json    # PWA manifest
└── package.json
```

## 🔐 Authentication Flow

1. **User registers/logs in** → Receives JWT token
2. **Token stored** in localStorage
3. **All API requests** include Authorization header
4. **Auto-logout** on 401 (expired token)
5. **Protected routes** redirect to login

## 📊 Features Breakdown

### Dashboard
- Total attempts, accuracy, avg time cards
- Recent performance history
- Category breakdown (planned)
- Quick action buttons

### Question Bank
- Browse all questions
- Filter by category, difficulty, tags (planned)
- Click to start practice

### Practice Mode
- Full question display with passage
- Interactive highlighting
- Option elimination
- Real-time behavioral tracking
- Submit and get instant feedback

### Analysis & Overlay
- Correctness indication
- AI-generated diagnoses with confidence scores
- Tier-based adaptive overlays
- Reasoning steps
- Micro-drill assignments

### Progress & Analytics
- Overall statistics
- Common diagnosis patterns
- Performance over time (planned charts)
- Weak area identification

## 🛠️ Development

### Environment Variables

Create `.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost:8001
NEXT_PUBLIC_APP_NAME=MCAT Platform
```

### Available Scripts

```bash
npm run dev      # Start dev server (port 3001)
npm run build    # Build for production
npm run start    # Start production server
npm run lint     # Run ESLint
```

### Adding Features

**New Page:**
1. Create `pages/yourpage.js`
2. Export default React component
3. Add navigation link in `index.js`

**New API Endpoint:**
1. Add to `lib/api.js`:
   ```js
   export const myFeature = {
     getData: () => api.get('/my-endpoint'),
   };
   ```

**New Global State:**
1. Add to `lib/store.js`:
   ```js
   export const useMyStore = create((set) => ({
     myData: null,
     setMyData: (data) => set({ myData: data }),
   }));
   ```

## 🔌 Backend Connection

This app connects to the FastAPI backend at `http://localhost:8001`.

**Required Backend Endpoints:**
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `GET /auth/me` - Get current user
- `POST /questions/search` - Search questions
- `GET /questions/{id}` - Get question by ID
- `POST /inference/analyze_attempt` - Submit answer
- `GET /users/me/progress` - Get user progress
- `GET /analytics/dashboard` - Get dashboard data

## 🧪 Testing

### Manual Testing

1. Start backend: `docker compose up -d fastapi_mobile`
2. Start frontend: `npm run dev`
3. Open http://localhost:3001
4. Register a new user
5. Browse questions
6. Start practice session
7. Submit answer
8. View analysis and overlay

### Test Credentials

Register new users or use these steps to create test data:

```bash
curl -X POST http://localhost:8001/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "premium@test.com",
    "username": "premiumuser",
    "password": "test123",
    "tier": "premium"
  }'
```

## 📱 PWA Installation

The app can be installed on mobile devices:

1. Open on mobile browser (Chrome/Safari)
2. Tap "Add to Home Screen"
3. App installs with icon
4. Opens in standalone mode (no browser UI)

## 🚢 Deployment

### Vercel (Recommended)

```bash
npm i -g vercel
vercel --prod
```

### Docker

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3001
CMD ["npm", "start"]
```

```bash
docker build -t mcat-mobile:latest .
docker run -p 3001:3001 mcat-mobile:latest
```

## 🎯 Roadmap

- [ ] TypeScript migration
- [ ] Performance charts (Recharts)
- [ ] Study session timer
- [ ] Bookmarking questions
- [ ] Spaced repetition algorithm
- [ ] Dark/light theme toggle
- [ ] Offline support (service worker)
- [ ] Push notifications
- [ ] Social features (leaderboards)

## 🔒 Security

- ✅ JWT authentication with expiry
- ✅ Token auto-refresh on 401
- ✅ XSS protection (React escaping)
- ✅ HTTPS only (production)
- ✅ CORS handled by backend
- ✅ Input validation

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

## 📄 License

MIT License - see LICENSE file

## 💖 Support

- Issues: https://github.com/Str8ZeRO1/n8n-workflows/issues
- Email: support@mcatplatform.com (example)

---

**Built with ❤️ for MCAT students**

Powered by Next.js, TailwindCSS, and FastAPI
