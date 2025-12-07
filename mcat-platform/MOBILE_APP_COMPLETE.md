# MCAT Platform - Complete Mobile App Production Code

## 🎉 What's Included

This is a **complete, production-ready** mobile-first PWA with dark theme.

### Features ✨
- 🌙 **Dark Theme** - Beautiful dark UI throughout
- 🔐 **Authentication** - JWT-based login/register
- 📊 **Dashboard** - Analytics and performance metrics
- 🎯 **Question Bank** - Browse and filter questions
- 📈 **Progress Tracking** - Detailed statistics
- ⚡ **Real-time Updates** - Live performance data
- 📱 **Mobile-First** - Optimized for all screen sizes
- 🎨 **Modern UI** - Tailwind CSS with custom dark palette

### Tech Stack
- **Frontend**: Next.js 14 + React 18 + TypeScript
- **Styling**: TailwindCSS (dark theme)
- **State**: Zustand
- **API**: Axios with interceptors
- **Charts**: Recharts
- **Animations**: Framer Motion
- **Toast**: React Hot Toast

---

## 📦 Installation

```bash
cd frontend-mobile

# Install dependencies
npm install

# Start development server (runs on port 3001)
npm run dev
```

Open **http://localhost:3001**

---

## 🔧 Backend Setup

The enhanced backend with authentication is in:
```
fastapi/app/main_mobile.py
```

**Updated Docker Compose:**

Add this to `docker-compose.yml`:

```yaml
fastapi_mobile:
  build:
    context: ./fastapi
    dockerfile: Dockerfile
  container_name: mcat_fastapi_mobile
  environment:
    - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/mcat
    - REDIS_URL=redis://redis:6379/0
    - JWT_SECRET=your-secret-key-change-in-production
    - PORT=8001
    - PYTHONPATH=/app
  ports:
    - "8001:8001"
  command: uvicorn app.main_mobile:app --host 0.0.0.0 --port 8001 --reload
  depends_on:
    - postgres
    - redis
  networks:
    - mcat-network
```

**Update Dockerfile** to install new dependencies:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc postgresql-client && rm -rf /var/lib/apt/lists/*

COPY requirements_mobile.txt .
RUN pip install --no-cache-dir -r requirements_mobile.txt

COPY app /app/app

RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8001

CMD ["uvicorn", "app.main_mobile:app", "--host", "0.0.0.0", "--port", "8001", "--reload"]
```

---

## 🚀 Quick Start

### 1. Start Backend

```bash
cd mcat-platform
docker compose up -d postgres redis
docker compose up -d fastapi_mobile
```

Wait for services to be ready (30 seconds)

### 2. Test Backend

```bash
# Health check
curl http://localhost:8001/health

# Register a user
curl -X POST http://localhost:8001/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "password123",
    "tier": "premium"
  }'
```

You'll receive a JWT token in the response.

### 3. Start Frontend

```bash
cd frontend-mobile
npm install
npm run dev
```

Open **http://localhost:3001**

---

## 📱 App Structure

```
frontend-mobile/
├── pages/
│   ├── index.tsx              # Landing/Login page
│   ├── dashboard.tsx          # Main dashboard
│   ├── practice.tsx           # Practice mode
│   ├── questions.tsx          # Question bank browser
│   ├── progress.tsx           # Progress & analytics
│   └── settings.tsx           # User settings
├── components/
│   ├── Layout.tsx             # App layout with navigation
│   ├── QuestionCard.tsx       # Question display component
│   ├── ProgressChart.tsx      # Performance charts
│   ├── StatsCard.tsx          # Stat display cards
│   └── ProtectedRoute.tsx     # Auth guard
├── lib/
│   ├── api.ts                 # API client (Axios)
│   ├── auth.ts                # Auth utilities
│   └── store.ts               # Zustand state management
└── styles/
    └── globals.css            # Global dark theme styles
```

---

## 🎨 Dark Theme Colors

```css
Background:     #0f172a  (slate-900)
Card:           #1e293b  (slate-800)
Border:         #334155  (slate-700)
Text:           #f1f5f9  (slate-100)
Muted:          #94a3b8  (slate-400)

Primary:        #3b82f6  (blue-500)
Success:        #10b981  (emerald-500)
Danger:         #ef4444  (red-500)
Warning:        #f59e0b  (amber-500)
```

---

## 📊 API Endpoints (Backend)

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login user
- `GET /auth/me` - Get current user (protected)

### Questions
- `POST /questions/search` - Search questions with filters
- `GET /questions/{id}` - Get single question

### Inference
- `POST /inference/analyze_attempt` - Submit answer and get analysis

### Analytics
- `GET /users/me/progress` - Get user progress stats
- `GET /analytics/dashboard` - Get dashboard data

### Utility
- `GET /` - API info
- `GET /health` - Health check

---

## 🔐 Authentication Flow

1. **Register/Login** → Receive JWT token
2. **Store token** in localStorage
3. **Include token** in all API requests (Authorization: Bearer {token})
4. **Auto-refresh** on 401 errors
5. **Protected routes** redirect to login if no token

---

## 🎯 Features Overview

### Dashboard
- Today's performance summary
- Weekly progress chart
- Category breakdown
- Recent attempts list
- Quick action buttons

### Practice Mode
- Select category and difficulty
- Timed practice sessions
- Real-time feedback
- Adaptive overlays based on tier
- Micro-drill assignments

### Question Bank
- Browse all questions
- Filter by category, difficulty, tags
- Search functionality
- Bookmark questions
- View attempt history per question

### Progress Tracking
- Overall statistics (accuracy, avg time)
- Performance over time (charts)
- Diagnosis patterns
- Weak areas identification
- Streaks and achievements

### Settings
- Profile management
- Tier upgrade
- Theme preferences
- Notification settings
- Study goals

---

## 🧪 Testing

### Manual Testing Checklist

- [ ] Register new user
- [ ] Login with credentials
- [ ] View dashboard (shows stats)
- [ ] Browse question bank
- [ ] Filter questions by category
- [ ] Start practice session
- [ ] Submit answer with behavioral events
- [ ] View adaptive overlay
- [ ] Check micro-drills
- [ ] View progress charts
- [ ] Update profile settings
- [ ] Logout and login again

### Automated Tests

```bash
# Run unit tests (after implementing)
npm test

# Run E2E tests
npm run test:e2e
```

---

## 🚢 Deployment

### Frontend (Vercel)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
cd frontend-mobile
vercel --prod
```

### Backend (Docker)

```bash
# Build production image
docker build -t mcat-api-mobile:latest -f fastapi/Dockerfile .

# Run on server
docker run -d \
  -p 8001:8001 \
  -e DATABASE_URL=postgresql://... \
  -e REDIS_URL=redis://... \
  -e JWT_SECRET=... \
  mcat-api-mobile:latest
```

### Environment Variables

Create `.env.local` in `frontend-mobile/`:

```env
NEXT_PUBLIC_API_URL=http://localhost:8001
NEXT_PUBLIC_APP_NAME=MCAT Platform
```

---

## 📈 Performance Optimizations

- ✅ Code splitting (Next.js automatic)
- ✅ Image optimization
- ✅ API response caching (Redis)
- ✅ Lazy loading components
- ✅ Debounced search
- ✅ Virtualized lists (for large question banks)
- ✅ Service worker (PWA)

---

## 🔒 Security

- ✅ JWT authentication with expiry
- ✅ Password hashing (bcrypt)
- ✅ HTTPS only (production)
- ✅ CORS configuration
- ✅ Input validation (Pydantic)
- ✅ SQL injection prevention (parameterized queries)
- ✅ XSS protection (React escaping)
- ✅ Rate limiting (TODO: add Redis-based limiter)

---

## 🛠️ Troubleshooting

### Backend won't start

```bash
# Check logs
docker logs mcat_fastapi_mobile

# Verify dependencies
pip install -r requirements_mobile.txt
```

### Frontend can't connect to API

1. Check API is running: `curl http://localhost:8001/health`
2. Check CORS settings in `main_mobile.py`
3. Verify `.env.local` has correct `NEXT_PUBLIC_API_URL`

### Authentication errors

1. Clear localStorage: `localStorage.clear()` in browser console
2. Check JWT_SECRET is consistent
3. Verify user exists in database: `docker exec -it mcat_postgres psql -U postgres -d mcat -c "SELECT * FROM users;"`

---

## 📞 Support

- **Issues**: https://github.com/Str8ZeRO1/n8n-workflows/issues
- **Docs**: See README files in `frontend-mobile/` and `fastapi/`

---

**🎉 Enjoy your production-ready MCAT mobile app!**

Built with ❤️ using Next.js, FastAPI, and PostgreSQL.
