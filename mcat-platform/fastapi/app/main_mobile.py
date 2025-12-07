"""
Enhanced MCAT Platform - Full-Stack Mobile API
Production-ready backend with authentication, analytics, and real-time features
"""

import os
import json
import time
import secrets
from typing import Any, Dict, List, Optional
from datetime import datetime, timedelta

from fastapi import FastAPI, HTTPException, Request, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field, EmailStr
import psycopg2
from psycopg2.extras import RealDictCursor
import redis
import jwt
from passlib.context import CryptContext

# Environment configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/mcat")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_urlsafe(32))
JWT_ALGORITHM = "HS256"
PORT = int(os.getenv("PORT", "8000"))

# Initialize
redis_client = redis.from_url(REDIS_URL, decode_responses=True)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

app = FastAPI(
    title="MCAT Platform API - Mobile",
    description="Full-featured mobile API with authentication and analytics",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:3001", "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# DATABASE UTILITIES
# ============================================================================

def get_db_connection():
    """Create a database connection"""
    try:
        conn = psycopg2.connect(DATABASE_URL)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        raise

def execute_query(query: str, params: tuple = None, fetch: bool = True):
    """Execute a database query"""
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, params)
            if fetch:
                result = cur.fetchall()
            else:
                result = None
            conn.commit()
            return result
    except Exception as e:
        conn.rollback()
        print(f"Query execution error: {e}")
        raise
    finally:
        conn.close()

# ============================================================================
# AUTHENTICATION MODELS
# ============================================================================

class UserRegister(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=8)
    tier: str = Field(default="free")

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: Dict[str, Any]

# ============================================================================
# EXISTING MODELS (from original main.py)
# ============================================================================

class Event(BaseModel):
    type: str
    value: Optional[str] = None
    timestamp_offset_ms: Optional[int] = None

class AttemptPayload(BaseModel):
    user_id: str
    question_id: str
    answer: str
    time_ms: int
    events: List[Event] = Field(default_factory=list)
    user_tier: str = Field(default="free")
    confidence_level: Optional[int] = None

class Diagnosis(BaseModel):
    name: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    explanation: str
    evidence: Dict[str, Any] = Field(default_factory=dict)

class Overlay(BaseModel):
    level: int
    insight: str
    steps: List[str]
    highlighted_terms: List[str] = Field(default_factory=list)
    visual_aids: Optional[Dict[str, Any]] = None

class MicroDrill(BaseModel):
    prompt: str
    answer: str
    difficulty: int

class AnalysisResponse(BaseModel):
    correct: bool
    correct_answer: str
    diagnoses: List[Diagnosis]
    overlay: Overlay
    drills: List[MicroDrill]
    debug: Dict[str, Any] = Field(default_factory=dict)

# ============================================================================
# NEW MODELS (Mobile App)
# ============================================================================

class QuestionFilter(BaseModel):
    category: Optional[str] = None
    difficulty: Optional[int] = None
    tags: Optional[List[str]] = None
    limit: int = 20
    offset: int = 0

class StudySession(BaseModel):
    user_id: str
    session_type: str = "practice"  # practice, timed, review
    target_count: int = 10

class UserProgress(BaseModel):
    total_attempts: int
    correct_count: int
    accuracy_pct: float
    avg_time_ms: int
    streak_days: int
    diagnoses_summary: List[Dict[str, Any]]

# ============================================================================
# AUTHENTICATION HELPERS
# ============================================================================

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(hours=24)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return encoded_jwt

def decode_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Dependency to get current authenticated user"""
    token = credentials.credentials
    payload = decode_token(token)
    user_id = payload.get("sub")

    if user_id is None:
        raise HTTPException(status_code=401, detail="Invalid authentication")

    # Fetch user from database
    query = "SELECT id, email, username, tier FROM users WHERE id::text = %s"
    result = execute_query(query, (user_id,))

    if not result:
        raise HTTPException(status_code=401, detail="User not found")

    return dict(result[0])

# ============================================================================
# INFERENCE LOGIC (from original)
# ============================================================================

def analyze_behavioral_signals(events: List[Event], time_ms: int) -> List[Diagnosis]:
    """Analyze behavioral events - same as original"""
    diagnoses = []

    change_events = [e for e in events if e.type == "change_answer"]
    if len(change_events) >= 2:
        diagnoses.append(Diagnosis(
            name="answer_oscillation",
            confidence=0.75 + (len(change_events) * 0.05),
            explanation="Multiple answer changes suggest uncertainty or premature closure.",
            evidence={"change_count": len(change_events)}
        ))

    highlight_events = [e for e in events if e.type == "highlight"]
    if len(highlight_events) == 0 and time_ms < 30000:
        diagnoses.append(Diagnosis(
            name="surface_reading",
            confidence=0.68,
            explanation="No text highlighting combined with quick completion suggests superficial analysis.",
            evidence={"time_ms": time_ms, "highlights": 0}
        ))

    kinetics_terms = ["inhibitor", "competitive", "km", "vmax", "enzyme", "velocity"]
    highlighted_text = " ".join([e.value.lower() for e in highlight_events if e.value])
    if any(term in highlighted_text for term in kinetics_terms):
        diagnoses.append(Diagnosis(
            name="pattern_recognition_kinetics",
            confidence=0.82,
            explanation="Highlighting enzyme kinetics terms shows concept awareness.",
            evidence={"highlighted_kinetics_terms": True}
        ))

    if time_ms < 15000:
        diagnoses.append(Diagnosis(
            name="hasty_selection",
            confidence=0.70,
            explanation="Very quick answer selection may indicate pattern matching.",
            evidence={"time_ms": time_ms}
        ))

    eliminate_events = [e for e in events if e.type == "eliminate_option"]
    if len(eliminate_events) >= 2:
        diagnoses.append(Diagnosis(
            name="systematic_elimination",
            confidence=0.80,
            explanation="Active elimination shows good test-taking strategy.",
            evidence={"eliminated_count": len(eliminate_events)}
        ))

    if not diagnoses:
        diagnoses.append(Diagnosis(
            name="low_signal",
            confidence=0.35,
            explanation="Insufficient behavioral data.",
            evidence={}
        ))

    return diagnoses

def generate_overlay(diagnoses: List[Diagnosis], question_data: Dict, tier: str) -> Overlay:
    """Generate overlay - same as original"""
    overlay_level = {"free": 1, "pro": 2, "premium": 3}.get(tier, 1)

    primary_diagnosis = max(diagnoses, key=lambda d: d.confidence) if diagnoses else None

    steps = [
        "Read the question stem to identify what is being asked",
        "Identify the manipulated variable",
        "Recall the conceptual relationship",
        "Map the concept to answer choices",
        "Eliminate distractors"
    ]

    insight = "Focus on identifying the manipulated variable before selecting an answer."

    if primary_diagnosis and "kinetics" in primary_diagnosis.name:
        insight = "You recognized kinetics concepts. Map them to the specific variable."
        if overlay_level >= 2:
            steps.insert(2, "Competitive inhibitor → ↑Km, Vmax unchanged")

    highlighted_terms = []
    if question_data:
        stem = question_data.get("stem", "")
        for term in ["inhibitor", "enzyme", "kinetics"]:
            if term in stem.lower():
                highlighted_terms.append(term)

    return Overlay(
        level=overlay_level,
        insight=insight,
        steps=steps[:overlay_level + 2],
        highlighted_terms=highlighted_terms
    )

def fetch_micro_drills(diagnoses: List[Diagnosis]) -> List[MicroDrill]:
    """Fetch drills - same as original"""
    try:
        diagnosis_names = [d.name for d in diagnoses]
        if not diagnosis_names:
            return []

        query = """
            SELECT drill_prompt, drill_answer, difficulty
            FROM micro_drills
            WHERE diagnosis_name = ANY(%s)
            LIMIT 3
        """
        results = execute_query(query, (diagnosis_names,))

        return [MicroDrill(
            prompt=row["drill_prompt"],
            answer=row["drill_answer"],
            difficulty=row["difficulty"]
        ) for row in results]
    except:
        return [MicroDrill(
            prompt="What happens to Km with competitive inhibitor?",
            answer="Km increases (apparent)",
            difficulty=2
        )]

# ============================================================================
# AUTHENTICATION ENDPOINTS
# ============================================================================

@app.post("/auth/register", response_model=TokenResponse)
async def register(user: UserRegister):
    """Register new user"""
    try:
        # Check if user exists
        check_query = "SELECT id FROM users WHERE email = %s OR username = %s"
        existing = execute_query(check_query, (user.email, user.username))

        if existing:
            raise HTTPException(status_code=400, detail="User already exists")

        # Hash password and insert user
        hashed_pwd = hash_password(user.password)
        insert_query = """
            INSERT INTO users (email, username, tier, settings, metadata)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id, email, username, tier
        """
        result = execute_query(
            insert_query,
            (user.email, user.username, user.tier, json.dumps({"theme": "dark"}), json.dumps({"password": hashed_pwd}))
        )

        new_user = dict(result[0])
        user_id = str(new_user["id"])

        # Create token
        access_token = create_access_token({"sub": user_id, "email": user.email})

        return TokenResponse(
            access_token=access_token,
            user={
                "id": user_id,
                "email": new_user["email"],
                "username": new_user["username"],
                "tier": new_user["tier"]
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/auth/login", response_model=TokenResponse)
async def login(credentials: UserLogin):
    """Login user"""
    try:
        query = "SELECT id, email, username, tier, metadata FROM users WHERE email = %s"
        result = execute_query(query, (credentials.email,))

        if not result:
            raise HTTPException(status_code=401, detail="Invalid credentials")

        user = dict(result[0])
        metadata = user.get("metadata", {})
        if isinstance(metadata, str):
            metadata = json.loads(metadata)

        stored_password = metadata.get("password", "")

        if not verify_password(credentials.password, stored_password):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        user_id = str(user["id"])
        access_token = create_access_token({"sub": user_id, "email": user["email"]})

        return TokenResponse(
            access_token=access_token,
            user={
                "id": user_id,
                "email": user["email"],
                "username": user["username"],
                "tier": user["tier"]
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/auth/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    """Get current user info"""
    return current_user

# ============================================================================
# MOBILE APP ENDPOINTS
# ============================================================================

@app.get("/")
def root():
    return {
        "service": "MCAT Platform API - Mobile",
        "version": "1.0.0",
        "status": "operational",
        "features": ["authentication", "analytics", "real-time", "mobile-optimized"]
    }

@app.get("/health")
def health_check():
    try:
        execute_query("SELECT 1", fetch=True)
        db_status = "ok"
    except:
        db_status = "error"

    try:
        redis_client.ping()
        redis_status = "ok"
    except:
        redis_status = "error"

    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "database": db_status,
        "redis": redis_status
    }

@app.post("/questions/search", response_model=List[Dict[str, Any]])
async def search_questions(filters: QuestionFilter, current_user: dict = Depends(get_current_user)):
    """Search questions with filters"""
    try:
        conditions = ["1=1"]
        params = []

        if filters.category:
            conditions.append("category = %s")
            params.append(filters.category)

        if filters.difficulty:
            conditions.append("difficulty = %s")
            params.append(filters.difficulty)

        if filters.tags:
            conditions.append("tags && %s")
            params.append(filters.tags)

        params.extend([filters.limit, filters.offset])

        query = f"""
            SELECT id, external_id, category, subcategory, difficulty, stem,
                   passage, options, tags, created_at
            FROM questions
            WHERE {' AND '.join(conditions)}
            ORDER BY created_at DESC
            LIMIT %s OFFSET %s
        """

        results = execute_query(query, tuple(params))
        return [dict(r) for r in results]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/questions/{question_id}")
async def get_question(question_id: str, current_user: dict = Depends(get_current_user)):
    """Get single question"""
    try:
        query = """
            SELECT id, external_id, category, subcategory, difficulty, stem, passage, options, tags
            FROM questions
            WHERE id::text = %s OR external_id = %s
            LIMIT 1
        """
        results = execute_query(query, (question_id, question_id))

        if not results:
            raise HTTPException(status_code=404, detail="Question not found")

        return dict(results[0])
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/inference/analyze_attempt", response_model=AnalysisResponse)
async def analyze_attempt(payload: AttemptPayload, current_user: dict = Depends(get_current_user)):
    """Main inference endpoint - enhanced with user context"""
    start_time = time.time()

    try:
        question_query = """
            SELECT id, external_id, correct_answer, stem, passage, options, explanation
            FROM questions
            WHERE id::text = %s OR external_id = %s
            LIMIT 1
        """
        question_results = execute_query(question_query, (payload.question_id, payload.question_id))

        if not question_results:
            raise HTTPException(status_code=404, detail="Question not found")

        question = dict(question_results[0])
        correct_answer = question["correct_answer"]
        is_correct = payload.answer.upper() == correct_answer.upper()

        diagnoses = analyze_behavioral_signals(payload.events, payload.time_ms)
        overlay = generate_overlay(diagnoses, question, current_user.get("tier", "free"))
        drills = fetch_micro_drills(diagnoses)

        # Store attempt
        attempt_insert = """
            INSERT INTO user_attempts (
                user_id, question_id, selected_option, correct, time_taken_ms,
                confidence_level, events, diagnoses, overlay_shown, drills_assigned
            ) VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """

        attempt_result = execute_query(
            attempt_insert,
            (
                current_user["id"], question["id"], payload.answer, is_correct, payload.time_ms,
                payload.confidence_level,
                json.dumps([e.dict() for e in payload.events]),
                json.dumps([d.dict() for d in diagnoses]),
                overlay.dict(),
                json.dumps([dr.dict() for dr in drills])
            )
        )

        attempt_id = attempt_result[0]["id"] if attempt_result else None

        # Store events
        if attempt_id and payload.events:
            for event in payload.events:
                event_insert = """
                    INSERT INTO reasoning_events (attempt_id, event_type, event_value, timestamp_offset_ms)
                    VALUES (%s, %s, %s, %s)
                """
                execute_query(event_insert, (attempt_id, event.type, event.value, event.timestamp_offset_ms or 0), fetch=False)

        # Store diagnoses
        if attempt_id and diagnoses:
            for diagnosis in diagnoses:
                diagnosis_insert = """
                    INSERT INTO cognitive_diagnoses (attempt_id, diagnosis_name, confidence, explanation, evidence)
                    VALUES (%s, %s, %s, %s, %s)
                """
                execute_query(diagnosis_insert, (attempt_id, diagnosis.name, diagnosis.confidence, diagnosis.explanation, json.dumps(diagnosis.evidence)), fetch=False)

        # Cache in Redis
        cache_key = f"user:{current_user['id']}:last_attempt"
        redis_client.hset(cache_key, mapping={
            "question_id": payload.question_id,
            "correct": str(is_correct),
            "time_ms": payload.time_ms,
            "timestamp": datetime.utcnow().isoformat(),
            "primary_diagnosis": diagnoses[0].name if diagnoses else "none"
        })
        redis_client.expire(cache_key, 3600)

        elapsed = time.time() - start_time

        return AnalysisResponse(
            correct=is_correct,
            correct_answer=correct_answer,
            diagnoses=diagnoses,
            overlay=overlay,
            drills=drills,
            debug={
                "duration_s": round(elapsed, 3),
                "attempt_id": attempt_id,
                "tier": current_user.get("tier", "free"),
                "events_count": len(payload.events)
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/users/me/progress", response_model=UserProgress)
async def get_user_progress(current_user: dict = Depends(get_current_user)):
    """Get user progress and statistics"""
    try:
        query = """
            SELECT
                COUNT(*) as total_attempts,
                SUM(CASE WHEN correct THEN 1 ELSE 0 END) as correct_count,
                ROUND(100.0 * SUM(CASE WHEN correct THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) as accuracy_pct,
                AVG(time_taken_ms)::int as avg_time_ms
            FROM user_attempts
            WHERE user_id::text = %s
        """
        stats = execute_query(query, (current_user["id"],))
        stats_dict = dict(stats[0]) if stats else {}

        # Get diagnosis summary
        diag_query = """
            SELECT diagnosis_name, COUNT(*) as count, AVG(confidence) as avg_confidence
            FROM cognitive_diagnoses cd
            JOIN user_attempts ua ON cd.attempt_id = ua.id
            WHERE ua.user_id::text = %s
            GROUP BY diagnosis_name
            ORDER BY count DESC
            LIMIT 5
        """
        diag_results = execute_query(diag_query, (current_user["id"],))

        return UserProgress(
            total_attempts=stats_dict.get("total_attempts", 0),
            correct_count=stats_dict.get("correct_count", 0),
            accuracy_pct=float(stats_dict.get("accuracy_pct", 0)),
            avg_time_ms=stats_dict.get("avg_time_ms", 0),
            streak_days=0,  # TODO: Calculate streak
            diagnoses_summary=[dict(d) for d in diag_results]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analytics/dashboard")
async def get_dashboard(current_user: dict = Depends(get_current_user)):
    """Get dashboard analytics"""
    try:
        # Recent performance
        recent_query = """
            SELECT
                DATE(created_at) as date,
                COUNT(*) as attempts,
                SUM(CASE WHEN correct THEN 1 ELSE 0 END) as correct,
                AVG(time_taken_ms)::int as avg_time
            FROM user_attempts
            WHERE user_id::text = %s AND created_at > NOW() - INTERVAL '30 days'
            GROUP BY DATE(created_at)
            ORDER BY date DESC
        """
        recent = execute_query(recent_query, (current_user["id"],))

        # Category breakdown
        category_query = """
            SELECT
                q.category,
                COUNT(*) as attempts,
                SUM(CASE WHEN ua.correct THEN 1 ELSE 0 END) as correct
            FROM user_attempts ua
            JOIN questions q ON ua.question_id = q.id
            WHERE ua.user_id::text = %s
            GROUP BY q.category
        """
        categories = execute_query(category_query, (current_user["id"],))

        return {
            "recent_performance": [dict(r) for r in recent],
            "category_breakdown": [dict(c) for c in categories]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.on_event("startup")
async def startup_event():
    print("🚀 MCAT Platform Mobile API starting...")
    print(f"🔐 JWT Authentication enabled")
    print(f"📊 Database: {DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else 'configured'}")
    print(f"📦 Redis: {REDIS_URL}")

    try:
        execute_query("SELECT 1")
        print("✅ Database connection: OK")
    except Exception as e:
        print(f"❌ Database connection: FAILED - {e}")

    try:
        redis_client.ping()
        print("✅ Redis connection: OK")
    except Exception as e:
        print(f"❌ Redis connection: FAILED - {e}")

@app.on_event("shutdown")
async def shutdown_event():
    print("🛑 MCAT Platform Mobile API shutting down...")
    redis_client.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT, reload=True)
