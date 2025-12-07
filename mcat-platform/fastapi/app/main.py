"""
MCAT Platform - FastAPI Inference Service
Main application handling reasoning analysis, overlay generation, and drill assignment
"""

import os
import json
import time
from typing import Any, Dict, List, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import psycopg2
from psycopg2.extras import RealDictCursor
import redis

# Environment configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/mcat")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
PORT = int(os.getenv("PORT", "8000"))

# Initialize Redis client
redis_client = redis.from_url(REDIS_URL, decode_responses=True)

# Initialize FastAPI app
app = FastAPI(
    title="MCAT Reasoning Platform API",
    description="AI-powered reasoning analysis and adaptive overlay generation",
    version="0.1.0"
)

# CORS middleware for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5678"],
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
# MODELS
# ============================================================================

class Event(BaseModel):
    """User interaction event"""
    type: str = Field(..., description="Event type: highlight, change_answer, eliminate_option, pause")
    value: Optional[str] = Field(None, description="Event value (e.g., highlighted text)")
    timestamp_offset_ms: Optional[int] = Field(None, description="Milliseconds from attempt start")

class AttemptPayload(BaseModel):
    """Answer submission payload"""
    user_id: str = Field(..., description="User UUID")
    question_id: str = Field(..., description="Question UUID or external_id")
    answer: str = Field(..., description="Selected option (A, B, C, D)")
    time_ms: int = Field(..., description="Total time taken in milliseconds")
    events: List[Event] = Field(default_factory=list, description="Behavioral events")
    user_tier: str = Field(default="free", description="User tier: free, pro, premium")
    confidence_level: Optional[int] = Field(None, description="User's confidence (1-5)")

class Diagnosis(BaseModel):
    """Cognitive diagnosis result"""
    name: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    explanation: str
    evidence: Dict[str, Any] = Field(default_factory=dict)

class Overlay(BaseModel):
    """Adaptive reasoning overlay"""
    level: int = Field(..., description="Overlay detail level (1-3)")
    insight: str = Field(..., description="Key insight for this question")
    steps: List[str] = Field(..., description="Step-by-step reasoning guidance")
    highlighted_terms: List[str] = Field(default_factory=list)
    visual_aids: Optional[Dict[str, Any]] = None

class MicroDrill(BaseModel):
    """Targeted practice drill"""
    prompt: str
    answer: str
    difficulty: int

class AnalysisResponse(BaseModel):
    """Full analysis response"""
    correct: bool
    correct_answer: str
    diagnoses: List[Diagnosis]
    overlay: Overlay
    drills: List[MicroDrill]
    debug: Dict[str, Any] = Field(default_factory=dict)

# ============================================================================
# REASONING ANALYSIS ENGINE (Mock)
# ============================================================================

def analyze_behavioral_signals(events: List[Event], time_ms: int) -> List[Diagnosis]:
    """
    Analyze behavioral events to detect reasoning patterns.

    This is a MOCK implementation using heuristics.
    In production, replace with:
    - LLM-based analysis using reasoning prompts from DB
    - RAG retrieval of similar patterns
    - Statistical models trained on labeled data
    """
    diagnoses = []

    # Pattern 1: Answer oscillation
    change_events = [e for e in events if e.type == "change_answer"]
    if len(change_events) >= 2:
        diagnoses.append(Diagnosis(
            name="answer_oscillation",
            confidence=0.75 + (len(change_events) * 0.05),
            explanation="Multiple answer changes suggest uncertainty or premature closure without systematic elimination.",
            evidence={"change_count": len(change_events)}
        ))

    # Pattern 2: Insufficient highlighting
    highlight_events = [e for e in events if e.type == "highlight"]
    if len(highlight_events) == 0 and time_ms < 30000:
        diagnoses.append(Diagnosis(
            name="surface_reading",
            confidence=0.68,
            explanation="No text highlighting combined with quick completion suggests superficial passage analysis.",
            evidence={"time_ms": time_ms, "highlights": 0}
        ))

    # Pattern 3: Kinetics pattern recognition
    kinetics_terms = ["inhibitor", "competitive", "km", "vmax", "enzyme", "velocity"]
    highlighted_text = " ".join([e.value.lower() for e in highlight_events if e.value])
    if any(term in highlighted_text for term in kinetics_terms):
        diagnoses.append(Diagnosis(
            name="pattern_recognition_kinetics",
            confidence=0.82,
            explanation="Highlighting enzyme kinetics terms indicates awareness of the concept but may need help connecting to manipulated variable.",
            evidence={"highlighted_kinetics_terms": True}
        ))

    # Pattern 4: Hasty selection
    if time_ms < 15000:
        diagnoses.append(Diagnosis(
            name="hasty_selection",
            confidence=0.70,
            explanation="Very quick answer selection may indicate pattern matching without reasoning through the experimental design.",
            evidence={"time_ms": time_ms}
        ))

    # Pattern 5: Elimination tracking
    eliminate_events = [e for e in events if e.type == "eliminate_option"]
    if len(eliminate_events) >= 2:
        diagnoses.append(Diagnosis(
            name="systematic_elimination",
            confidence=0.80,
            explanation="Active elimination of distractors shows good test-taking strategy.",
            evidence={"eliminated_count": len(eliminate_events)}
        ))

    # Default if no clear pattern
    if not diagnoses:
        diagnoses.append(Diagnosis(
            name="low_signal",
            confidence=0.35,
            explanation="Insufficient behavioral data to identify specific reasoning patterns.",
            evidence={}
        ))

    return diagnoses

def generate_overlay(diagnoses: List[Diagnosis], question_data: Dict, tier: str) -> Overlay:
    """
    Generate adaptive overlay based on diagnoses and user tier.

    In production:
    - Retrieve reasoning_prompts from DB by tier
    - Use LLM to generate personalized overlay
    - Include visual aids (concept maps, graphs)
    """
    overlay_level = {"free": 1, "pro": 2, "premium": 3}.get(tier, 1)

    # Extract primary diagnosis
    primary_diagnosis = max(diagnoses, key=lambda d: d.confidence) if diagnoses else None

    # Base overlay
    steps = [
        "Read the question stem to identify what is being asked",
        "Identify the manipulated variable in the experimental setup",
        "Recall the conceptual relationship (e.g., competitive inhibitor → ↑Km, Vmax unchanged)",
        "Map the concept to the answer choices",
        "Eliminate distractors that reference unrelated variables"
    ]

    insight = "Focus on identifying the manipulated variable before selecting an answer."

    # Customize by diagnosis
    if primary_diagnosis and "kinetics" in primary_diagnosis.name:
        insight = "You recognized enzyme kinetics concepts. Now map them to the specific manipulated variable."
        if overlay_level >= 2:
            steps.insert(2, "Competitive inhibitor → increases apparent Km (more substrate needed to reach Vmax/2)")
        if overlay_level == 3:
            steps.append("Visual aid: Plot [S] vs V curve with and without inhibitor to see Km shift")

    elif primary_diagnosis and "oscillation" in primary_diagnosis.name:
        insight = "You changed your answer multiple times. Use systematic elimination to increase confidence."
        if overlay_level >= 2:
            steps.insert(1, "Cross out definitively wrong answers first")

    highlighted_terms = []
    if question_data:
        # Extract key terms from question
        stem = question_data.get("stem", "")
        if "inhibitor" in stem.lower():
            highlighted_terms.append("inhibitor")
        if "enzyme" in stem.lower():
            highlighted_terms.append("enzyme")

    overlay = Overlay(
        level=overlay_level,
        insight=insight,
        steps=steps[:overlay_level + 2],  # More steps for higher tiers
        highlighted_terms=highlighted_terms
    )

    return overlay

def fetch_micro_drills(diagnoses: List[Diagnosis]) -> List[MicroDrill]:
    """
    Fetch relevant micro-drills from database based on diagnoses.

    In production:
    - Query micro_drills table filtered by diagnosis_name
    - Personalize difficulty based on user history
    """
    try:
        diagnosis_names = tuple([d.name for d in diagnoses])
        if not diagnosis_names:
            return []

        query = """
            SELECT drill_prompt, drill_answer, difficulty
            FROM micro_drills
            WHERE diagnosis_name = ANY(%s)
            LIMIT 3
        """
        results = execute_query(query, (list(diagnosis_names),))

        drills = [
            MicroDrill(
                prompt=row["drill_prompt"],
                answer=row["drill_answer"],
                difficulty=row["difficulty"]
            )
            for row in results
        ]

        return drills
    except Exception as e:
        print(f"Error fetching drills: {e}")
        # Fallback mock drills
        return [
            MicroDrill(
                prompt="What happens to Km when a competitive inhibitor is added?",
                answer="Km increases (apparent Km)",
                difficulty=2
            )
        ]

# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/")
def root():
    """Root endpoint"""
    return {
        "service": "MCAT Reasoning Platform API",
        "version": "0.1.0",
        "status": "operational",
        "endpoints": {
            "health": "/health",
            "inference": "/inference/analyze_attempt",
            "docs": "/docs"
        }
    }

@app.get("/health")
def health_check():
    """Health check endpoint"""
    try:
        # Check database
        execute_query("SELECT 1", fetch=True)
        db_status = "ok"
    except Exception as e:
        db_status = f"error: {str(e)}"

    try:
        # Check Redis
        redis_client.ping()
        redis_status = "ok"
    except Exception as e:
        redis_status = f"error: {str(e)}"

    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "database": db_status,
        "redis": redis_status
    }

@app.post("/inference/analyze_attempt", response_model=AnalysisResponse)
async def analyze_attempt(payload: AttemptPayload):
    """
    Main inference endpoint: analyze answer attempt and return adaptive overlay.

    Flow:
    1. Fetch question from DB
    2. Determine correctness
    3. Analyze behavioral signals → diagnoses
    4. Generate tier-appropriate overlay
    5. Fetch relevant micro-drills
    6. Store attempt + events + diagnoses in DB
    7. Cache result in Redis
    """
    start_time = time.time()

    try:
        # 1. Fetch question
        question_query = """
            SELECT id, external_id, correct_answer, stem, passage, options, explanation
            FROM questions
            WHERE id::text = %s OR external_id = %s
            LIMIT 1
        """
        question_results = execute_query(
            question_query,
            (payload.question_id, payload.question_id)
        )

        if not question_results:
            raise HTTPException(status_code=404, detail=f"Question {payload.question_id} not found")

        question = dict(question_results[0])
        correct_answer = question["correct_answer"]
        is_correct = payload.answer.upper() == correct_answer.upper()

        # 2. Analyze behavioral signals
        diagnoses = analyze_behavioral_signals(payload.events, payload.time_ms)

        # 3. Generate overlay
        overlay = generate_overlay(diagnoses, question, payload.user_tier)

        # 4. Fetch micro-drills
        drills = fetch_micro_drills(diagnoses)

        # 5. Store attempt in database
        attempt_insert = """
            INSERT INTO user_attempts (
                user_id, question_id, selected_option, correct, time_taken_ms,
                confidence_level, events, diagnoses, overlay_shown, drills_assigned
            ) VALUES (
                %s::uuid, %s::uuid, %s, %s, %s, %s, %s, %s, %s, %s
            ) RETURNING id
        """

        attempt_result = execute_query(
            attempt_insert,
            (
                payload.user_id,
                question["id"],
                payload.answer,
                is_correct,
                payload.time_ms,
                payload.confidence_level,
                json.dumps([e.dict() for e in payload.events]),
                json.dumps([d.dict() for d in diagnoses]),
                overlay.dict(),
                json.dumps([dr.dict() for dr in drills])
            )
        )

        attempt_id = attempt_result[0]["id"] if attempt_result else None

        # 6. Store individual reasoning events
        if attempt_id and payload.events:
            for event in payload.events:
                event_insert = """
                    INSERT INTO reasoning_events (attempt_id, event_type, event_value, timestamp_offset_ms)
                    VALUES (%s, %s, %s, %s)
                """
                execute_query(
                    event_insert,
                    (attempt_id, event.type, event.value, event.timestamp_offset_ms or 0),
                    fetch=False
                )

        # 7. Store cognitive diagnoses
        if attempt_id and diagnoses:
            for diagnosis in diagnoses:
                diagnosis_insert = """
                    INSERT INTO cognitive_diagnoses (attempt_id, diagnosis_name, confidence, explanation, evidence)
                    VALUES (%s, %s, %s, %s, %s)
                """
                execute_query(
                    diagnosis_insert,
                    (attempt_id, diagnosis.name, diagnosis.confidence, diagnosis.explanation, json.dumps(diagnosis.evidence)),
                    fetch=False
                )

        # 8. Cache in Redis for quick dashboard access
        cache_key = f"user:{payload.user_id}:last_attempt"
        redis_client.hset(cache_key, mapping={
            "question_id": payload.question_id,
            "correct": str(is_correct),
            "time_ms": payload.time_ms,
            "timestamp": datetime.utcnow().isoformat(),
            "primary_diagnosis": diagnoses[0].name if diagnoses else "none"
        })
        redis_client.expire(cache_key, 3600)  # 1 hour TTL

        # 9. Build response
        elapsed = time.time() - start_time

        response = AnalysisResponse(
            correct=is_correct,
            correct_answer=correct_answer,
            diagnoses=diagnoses,
            overlay=overlay,
            drills=drills,
            debug={
                "duration_s": round(elapsed, 3),
                "attempt_id": attempt_id,
                "tier": payload.user_tier,
                "events_count": len(payload.events)
            }
        )

        return response

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in analyze_attempt: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/questions/{question_id}")
def get_question(question_id: str):
    """Fetch a question by ID or external_id"""
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

@app.get("/users/{user_id}/performance")
def get_user_performance(user_id: str):
    """Get user performance summary"""
    try:
        query = """
            SELECT * FROM user_performance_summary
            WHERE user_id::text = %s
        """
        results = execute_query(query, (user_id,))

        if not results:
            raise HTTPException(status_code=404, detail="User not found")

        return dict(results[0])

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/analytics/diagnoses")
def get_common_diagnoses():
    """Get most common cognitive diagnoses across all users"""
    try:
        query = "SELECT * FROM common_diagnoses LIMIT 10"
        results = execute_query(query)
        return [dict(row) for row in results]

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ============================================================================
# STARTUP / SHUTDOWN
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Application startup tasks"""
    print("🚀 MCAT Reasoning Platform API starting...")
    print(f"📊 Database: {DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else 'configured'}")
    print(f"📦 Redis: {REDIS_URL}")

    # Test connections
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
    """Application shutdown tasks"""
    print("🛑 MCAT Reasoning Platform API shutting down...")
    redis_client.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT, reload=True)
