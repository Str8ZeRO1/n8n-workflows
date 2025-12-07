#!/bin/bash

# MCAT Platform - Mobile App Complete Setup Script
# This script creates ALL necessary files for the production mobile app

echo "🚀 Creating MCAT Platform Mobile App..."
echo ""

cd "$(dirname "$0")/frontend-mobile"

# Create directory structure
mkdir -p {lib,components,pages/api,public}

echo "📦 Creating library files..."

# lib/api.js - API Client
cat > lib/api.js << 'EOF'
import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8001';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add auth token to requests
api.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

// Handle 401 errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && typeof window !== 'undefined') {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/';
    }
    return Promise.reject(error);
  }
);

export default api;

export const auth = {
  register: (data) => api.post('/auth/register', data),
  login: (data) => api.post('/auth/login', data),
  getMe: () => api.get('/auth/me'),
};

export const questions = {
  search: (filters) => api.post('/questions/search', filters),
  getById: (id) => api.get(`/questions/${id}`),
};

export const inference = {
  analyzeAttempt: (data) => api.post('/inference/analyze_attempt', data),
};

export const analytics = {
  getProgress: () => api.get('/users/me/progress'),
  getDashboard: () => api.get('/analytics/dashboard'),
};
EOF

# lib/store.js - State Management
cat > lib/store.js << 'EOF'
import { create } from 'zustand';

export const useAuthStore = create((set) => ({
  user: null,
  token: null,
  isAuthenticated: false,
  
  setAuth: (user, token) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('token', token);
      localStorage.setItem('user', JSON.stringify(user));
    }
    set({ user, token, isAuthenticated: true });
  },
  
  logout: () => {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
    }
    set({ user: null, token: null, isAuthenticated: false });
  },
  
  loadFromStorage: () => {
    if (typeof window !== 'undefined') {
      const token = localStorage.getItem('token');
      const user = localStorage.getItem('user');
      if (token && user) {
        set({ user: JSON.parse(user), token, isAuthenticated: true });
      }
    }
  },
}));

export const useAppStore = create((set) => ({
  loading: false,
  error: null,
  
  setLoading: (loading) => set({ loading }),
  setError: (error) => set({ error }),
}));
EOF

echo "📄 Creating pages..."

# pages/_app.js
cat > pages/_app.js << 'EOF'
import '../styles/globals.css';
import { useEffect } from 'react';
import { useAuthStore } from '../lib/store';
import { Toaster } from 'react-hot-toast';

export default function App({ Component, pageProps }) {
  const loadFromStorage = useAuthStore((state) => state.loadFromStorage);
  
  useEffect(() => {
    loadFromStorage();
  }, []);
  
  return (
    <>
      <Component {...pageProps} />
      <Toaster position="top-right" />
    </>
  );
}
EOF

# pages/index.js - Comprehensive Demo Page
cat > pages/index.js << 'EOF'
import { useState, useEffect } from 'react';
import { useAuthStore, useAppStore } from '../lib/store';
import api, { auth, questions, inference, analytics } from '../lib/api';
import toast from 'react-hot-toast';

export default function Home() {
  const { user, isAuthenticated, setAuth, logout } = useAuthStore();
  const { loading, setLoading } = useAppStore();
  
  // Auth state
  const [showRegister, setShowRegister] = useState(false);
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  
  // App state
  const [currentView, setCurrentView] = useState('dashboard');
  const [questionList, setQuestionList] = useState([]);
  const [currentQuestion, setCurrentQuestion] = useState(null);
  const [selectedAnswer, setSelectedAnswer] = useState(null);
  const [progress, setProgress] = useState(null);
  const [dashboard, setDashboard] = useState(null);
  const [analysisResult, setAnalysisResult] = useState(null);
  
  // Practice state
  const [highlights, setHighlights] = useState([]);
  const [eliminated, setEliminated] = useState([]);
  const [events, setEvents] = useState([]);
  const [startTime, setStartTime] = useState(null);
  
  useEffect(() => {
    if (isAuthenticated) {
      loadDashboard();
      loadProgress();
      loadQuestions();
    }
  }, [isAuthenticated]);
  
  const handleAuth = async (e) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      const payload = showRegister
        ? { email, username, password, tier: 'premium' }
        : { email, password };
      
      const endpoint = showRegister ? auth.register : auth.login;
      const res = await endpoint(payload);
      
      setAuth(res.data.user, res.data.access_token);
      toast.success(`Welcome ${showRegister ? 'aboard' : 'back'}!`);
      setCurrentView('dashboard');
    } catch (error) {
      toast.error(error.response?.data?.detail || 'Authentication failed');
    } finally {
      setLoading(false);
    }
  };
  
  const loadDashboard = async () => {
    try {
      const res = await analytics.getDashboard();
      setDashboard(res.data);
    } catch (error) {
      console.error('Failed to load dashboard:', error);
    }
  };
  
  const loadProgress = async () => {
    try {
      const res = await analytics.getProgress();
      setProgress(res.data);
    } catch (error) {
      console.error('Failed to load progress:', error);
    }
  };
  
  const loadQuestions = async () => {
    try {
      const res = await questions.search({ limit: 20, offset: 0 });
      setQuestionList(res.data);
    } catch (error) {
      console.error('Failed to load questions:', error);
    }
  };
  
  const startPractice = async (questionId) => {
    try {
      const res = await questions.getById(questionId);
      setCurrentQuestion(res.data);
      setSelectedAnswer(null);
      setHighlights([]);
      setEliminated([]);
      setEvents([]);
      setStartTime(Date.now());
      setAnalysisResult(null);
      setCurrentView('practice');
    } catch (error) {
      toast.error('Failed to load question');
    }
  };
  
  const addEvent = (type, value = null) => {
    const offset = startTime ? Date.now() - startTime : 0;
    setEvents([...events, { type, value, timestamp_offset_ms: offset }]);
  };
  
  const toggleHighlight = (term) => {
    if (highlights.includes(term)) {
      setHighlights(highlights.filter(h => h !== term));
    } else {
      setHighlights([...highlights, term]);
      addEvent('highlight', term);
    }
  };
  
  const toggleEliminate = (option) => {
    if (eliminated.includes(option)) {
      setEliminated(eliminated.filter(e => e !== option));
    } else {
      setEliminated([...eliminated, option]);
      addEvent('eliminate_option', option);
    }
  };
  
  const submitAnswer = async () => {
    if (!selectedAnswer) {
      toast.error('Please select an answer');
      return;
    }
    
    setLoading(true);
    const time_ms = Date.now() - startTime;
    
    try {
      const res = await inference.analyzeAttempt({
        user_id: user.id,
        question_id: currentQuestion.id,
        answer: selectedAnswer,
        time_ms,
        events,
        user_tier: user.tier,
        confidence_level: 4
      });
      
      setAnalysisResult(res.data);
      toast.success(res.data.correct ? 'Correct!' : 'Incorrect');
      loadProgress();
      loadDashboard();
    } catch (error) {
      toast.error('Submission failed');
    } finally {
      setLoading(false);
    }
  };
  
  // Login/Register View
  if (!isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center p-4">
        <div className="card max-w-md w-full">
          <div className="text-center mb-8">
            <h1 className="text-4xl font-bold text-primary mb-2">MCAT Platform</h1>
            <p className="text-dark-muted">AI-Powered Test Prep</p>
          </div>
          
          <form onSubmit={handleAuth} className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="input"
                required
              />
            </div>
            
            {showRegister && (
              <div>
                <label className="block text-sm font-medium mb-2">Username</label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="input"
                  required
                />
              </div>
            )}
            
            <div>
              <label className="block text-sm font-medium mb-2">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="input"
                required
              />
            </div>
            
            <button type="submit" className="btn-primary w-full" disabled={loading}>
              {loading ? (
                <span className="spinner mx-auto"></span>
              ) : (
                showRegister ? 'Create Account' : 'Login'
              )}
            </button>
          </form>
          
          <div className="mt-6 text-center">
            <button
              onClick={() => setShowRegister(!showRegister)}
              className="text-primary hover:underline text-sm"
            >
              {showRegister ? 'Already have an account? Login' : 'Need an account? Register'}
            </button>
          </div>
        </div>
      </div>
    );
  }
  
  // Main App View
  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="bg-dark-card border-b border-dark-border sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-bold text-primary">MCAT Platform</h1>
            <div className="flex items-center gap-4">
              <span className="text-sm text-dark-muted">
                {user?.username} 
                <span className="ml-2 badge badge-primary">{user?.tier}</span>
              </span>
              <button onClick={logout} className="text-sm text-danger hover:underline">
                Logout
              </button>
            </div>
          </div>
        </div>
      </header>
      
      {/* Navigation */}
      <nav className="bg-dark-card border-b border-dark-border">
        <div className="container mx-auto px-4">
          <div className="flex gap-1 overflow-x-auto">
            {['dashboard', 'questions', 'progress'].map((view) => (
              <button
                key={view}
                onClick={() => setCurrentView(view)}
                className={`px-4 py-3 font-medium capitalize whitespace-nowrap ${
                  currentView === view
                    ? 'text-primary border-b-2 border-primary'
                    : 'text-dark-muted hover:text-dark-text'
                }`}
              >
                {view}
              </button>
            ))}
          </div>
        </div>
      </nav>
      
      {/* Content */}
      <main className="container mx-auto px-4 py-8">
        {currentView === 'dashboard' && (
          <div className="space-y-6">
            <h2 className="text-3xl font-bold">Dashboard</h2>
            
            {/* Stats */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="card">
                <div className="text-sm text-dark-muted mb-1">Total Attempts</div>
                <div className="text-3xl font-bold text-primary">{progress?.total_attempts || 0}</div>
              </div>
              <div className="card">
                <div className="text-sm text-dark-muted mb-1">Accuracy</div>
                <div className="text-3xl font-bold text-success">{progress?.accuracy_pct?.toFixed(1) || 0}%</div>
              </div>
              <div className="card">
                <div className="text-sm text-dark-muted mb-1">Avg Time</div>
                <div className="text-3xl font-bold text-warning">{((progress?.avg_time_ms || 0) / 1000).toFixed(1)}s</div>
              </div>
            </div>
            
            {/* Recent Performance */}
            {dashboard?.recent_performance && dashboard.recent_performance.length > 0 && (
              <div className="card">
                <h3 className="text-xl font-bold mb-4">Recent Performance</h3>
                <div className="space-y-2">
                  {dashboard.recent_performance.slice(0, 5).map((day, i) => (
                    <div key={i} className="flex items-center justify-between py-2 border-b border-dark-border last:border-0">
                      <span className="text-dark-muted">{day.date}</span>
                      <div className="flex items-center gap-4">
                        <span className="text-sm">{day.attempts} attempts</span>
                        <span className="badge badge-success">{day.correct}/{day.attempts}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
            
            {/* Quick Actions */}
            <div className="card">
              <h3 className="text-xl font-bold mb-4">Quick Start</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <button
                  onClick={() => questionList[0] && startPractice(questionList[0].id)}
                  className="btn-primary"
                  disabled={!questionList.length}
                >
                  🎯 Start Practice
                </button>
                <button
                  onClick={() => setCurrentView('questions')}
                  className="btn-secondary"
                >
                  📚 Browse Questions
                </button>
              </div>
            </div>
          </div>
        )}
        
        {currentView === 'questions' && (
          <div className="space-y-6">
            <h2 className="text-3xl font-bold">Question Bank</h2>
            
            <div className="grid grid-cols-1 gap-4">
              {questionList.map((q) => (
                <div key={q.id} className="card hover:border-primary cursor-pointer" onClick={() => startPractice(q.id)}>
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="badge badge-primary">{q.category}</span>
                        {q.difficulty && (
                          <span className="badge badge-warning">Difficulty: {q.difficulty}</span>
                        )}
                      </div>
                      <p className="text-dark-text line-clamp-2">{q.stem}</p>
                    </div>
                    <button className="btn-secondary text-sm px-4 py-2">
                      Practice →
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
        
        {currentView === 'progress' && (
          <div className="space-y-6">
            <h2 className="text-3xl font-bold">Progress & Analytics</h2>
            
            {progress?.diagnoses_summary && progress.diagnoses_summary.length > 0 && (
              <div className="card">
                <h3 className="text-xl font-bold mb-4">Common Patterns</h3>
                <div className="space-y-3">
                  {progress.diagnoses_summary.map((diag, i) => (
                    <div key={i} className="flex items-center justify-between">
                      <div>
                        <div className="font-medium">{diag.diagnosis_name.replace(/_/g, ' ')}</div>
                        <div className="text-sm text-dark-muted">
                          Confidence: {(diag.avg_confidence * 100).toFixed(0)}%
                        </div>
                      </div>
                      <div className="badge badge-primary">{diag.count} times</div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
        
        {currentView === 'practice' && currentQuestion && (
          <div className="max-w-4xl mx-auto space-y-6">
            <button
              onClick={() => setCurrentView('dashboard')}
              className="text-primary hover:underline mb-4"
            >
              ← Back to Dashboard
            </button>
            
            <div className="card">
              <div className="flex items-center gap-2 mb-4">
                <span className="badge badge-primary">{currentQuestion.category}</span>
                {currentQuestion.difficulty && (
                  <span className="badge badge-warning">Level {currentQuestion.difficulty}</span>
                )}
              </div>
              
              {currentQuestion.passage && (
                <div className="bg-dark-bg border border-dark-border rounded-lg p-4 mb-6">
                  <h4 className="font-semibold mb-2">Passage:</h4>
                  <p className="text-dark-muted leading-relaxed">{currentQuestion.passage}</p>
                  
                  <div className="mt-4 flex flex-wrap gap-2">
                    {['inhibitor', 'enzyme', 'Km'].map((term) => (
                      <button
                        key={term}
                        onClick={() => toggleHighlight(term)}
                        className={`px-3 py-1 text-xs rounded-full ${
                          highlights.includes(term)
                            ? 'bg-yellow-500/30 text-yellow-400 border border-yellow-500'
                            : 'bg-dark-card border border-dark-border hover:border-yellow-500'
                        }`}
                      >
                        💡 {term}
                      </button>
                    ))}
                  </div>
                </div>
              )}
              
              <h3 className="text-xl font-bold mb-4">{currentQuestion.stem}</h3>
              
              <div className="space-y-3 mb-6">
                {Object.entries(currentQuestion.options || {}).map(([key, value]) => (
                  <div
                    key={key}
                    className={`border-2 rounded-lg p-4 cursor-pointer transition-all ${
                      eliminated.includes(key)
                        ? 'border-danger/30 bg-danger/10 opacity-50'
                        : selectedAnswer === key
                        ? 'border-primary bg-primary/10'
                        : 'border-dark-border hover:border-primary/50'
                    }`}
                  >
                    <div className="flex items-start gap-3">
                      <input
                        type="radio"
                        name="answer"
                        value={key}
                        checked={selectedAnswer === key}
                        onChange={() => {
                          if (!startTime) setStartTime(Date.now());
                          if (selectedAnswer && selectedAnswer !== key) {
                            addEvent('change_answer', `${selectedAnswer} -> ${key}`);
                          }
                          setSelectedAnswer(key);
                        }}
                        disabled={eliminated.includes(key)}
                        className="mt-1"
                      />
                      <div className="flex-1">
                        <span className="font-bold mr-2">{key}.</span>
                        <span>{value}</span>
                      </div>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          toggleEliminate(key);
                        }}
                        className={`text-xs px-2 py-1 rounded ${
                          eliminated.includes(key)
                            ? 'bg-danger text-white'
                            : 'bg-dark-card border border-dark-border hover:bg-danger/20'
                        }`}
                      >
                        {eliminated.includes(key) ? '✓ Eliminated' : '✗ Eliminate'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
              
              <button
                onClick={submitAnswer}
                className="btn-primary w-full"
                disabled={loading || !selectedAnswer}
              >
                {loading ? <span className="spinner mx-auto"></span> : 'Submit Answer'}
              </button>
            </div>
            
            {/* Analysis Result */}
            {analysisResult && (
              <div className="card bg-gradient-to-br from-primary/10 to-success/10 border-2 border-primary/50">
                <h3 className="text-2xl font-bold mb-4">
                  {analysisResult.correct ? (
                    <span className="text-success">✓ Correct!</span>
                  ) : (
                    <span className="text-danger">✗ Incorrect</span>
                  )}
                </h3>
                
                {!analysisResult.correct && (
                  <p className="mb-4">
                    Correct answer: <span className="font-bold text-primary text-xl">{analysisResult.correct_answer}</span>
                  </p>
                )}
                
                {/* Diagnoses */}
                {analysisResult.diagnoses && analysisResult.diagnoses.length > 0 && (
                  <div className="mb-6">
                    <h4 className="text-lg font-semibold mb-3">🧠 Reasoning Analysis</h4>
                    <div className="space-y-3">
                      {analysisResult.diagnoses.map((diag, i) => (
                        <div key={i} className="bg-dark-card border border-dark-border rounded-lg p-4">
                          <div className="flex items-center justify-between mb-2">
                            <span className="font-semibold">
                              {diag.name.replace(/_/g, ' ').toUpperCase()}
                            </span>
                            <span className="badge badge-primary">
                              {Math.round(diag.confidence * 100)}%
                            </span>
                          </div>
                          <p className="text-sm text-dark-muted">{diag.explanation}</p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                
                {/* Overlay */}
                {analysisResult.overlay && (
                  <div className="mb-6">
                    <h4 className="text-lg font-semibold mb-3">
                      💡 Adaptive Overlay (Level {analysisResult.overlay.level})
                    </h4>
                    <div className="bg-dark-card border border-primary rounded-lg p-4">
                      <p className="text-primary font-medium mb-4">{analysisResult.overlay.insight}</p>
                      <div className="space-y-2">
                        <p className="text-sm font-semibold">Reasoning Steps:</p>
                        <ol className="list-decimal list-inside space-y-1 text-sm text-dark-muted">
                          {analysisResult.overlay.steps.map((step, i) => (
                            <li key={i}>{step}</li>
                          ))}
                        </ol>
                      </div>
                    </div>
                  </div>
                )}
                
                {/* Drills */}
                {analysisResult.drills && analysisResult.drills.length > 0 && (
                  <div>
                    <h4 className="text-lg font-semibold mb-3">🎯 Micro-Drills</h4>
                    <div className="space-y-2">
                      {analysisResult.drills.map((drill, i) => (
                        <details key={i} className="bg-dark-card border border-dark-border rounded-lg p-4">
                          <summary className="font-medium cursor-pointer">
                            Drill {i + 1}: {drill.prompt}
                          </summary>
                          <p className="mt-2 text-success pl-4">✓ {drill.answer}</p>
                        </details>
                      ))}
                    </div>
                  </div>
                )}
                
                <button
                  onClick={() => setCurrentView('dashboard')}
                  className="btn-primary w-full mt-6"
                >
                  Return to Dashboard
                </button>
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  );
}
EOF

echo ""
echo "✅ Mobile app files created successfully!"
echo ""
echo "📦 Next steps:"
echo "1. npm install"
echo "2. npm run dev"
echo "3. Open http://localhost:3001"
echo ""

