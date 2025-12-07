# MCAT Platform - File Structure

This document provides an overview of all files in the MCAT Platform starter.

## Directory Tree

```
mcat-platform/
├── .github/
│   └── workflows/
│       └── ci.yml                      # GitHub Actions CI pipeline
├── db/
│   └── migrations/
│       └── 001_initial_schema.sql      # PostgreSQL schema with pgvector
├── fastapi/
│   ├── app/
│   │   ├── __init__.py                 # Python package marker
│   │   └── main.py                     # FastAPI application (inference API)
│   ├── Dockerfile                      # FastAPI container definition
│   └── requirements.txt                # Python dependencies
├── frontend/
│   ├── pages/
│   │   ├── _app.jsx                    # Next.js app wrapper
│   │   └── index.jsx                   # Question Player (main page)
│   ├── styles/
│   │   └── globals.css                 # TailwindCSS styles
│   ├── next.config.js                  # Next.js configuration
│   ├── package.json                    # npm dependencies
│   ├── postcss.config.js               # PostCSS config for Tailwind
│   └── tailwind.config.js              # TailwindCSS configuration
├── n8n/
│   ├── mcat-workflow.json              # Full n8n workflow (with logging)
│   └── mcat-workflow-simple.json       # Simple n8n workflow (quickstart)
├── .env.example                        # Environment variables template
├── .gitignore                          # Git ignore rules
├── docker-compose.yml                  # Docker Compose orchestration
├── README.md                           # Main documentation
├── start.sh                            # Quick start script
└── STRUCTURE.md                        # This file

```

## File Descriptions

### Core Infrastructure

- **docker-compose.yml**: Orchestrates 4 services (Postgres, Redis, n8n, FastAPI)
- **start.sh**: Bash script to start all services and run health checks

### Database

- **db/migrations/001_initial_schema.sql**:
  - Creates 12 tables (users, questions, user_attempts, reasoning_events, cognitive_diagnoses, etc.)
  - Enables pgvector extension for semantic search
  - Includes seed data (3 users, 1 question, 2 concepts, 2 drills)
  - Defines views for analytics
  - Sets up HNSW indexes for vector similarity search

### Backend (FastAPI)

- **fastapi/Dockerfile**: Python 3.11 container with health checks
- **fastapi/requirements.txt**: Dependencies (FastAPI, psycopg2, redis, pgvector)
- **fastapi/app/main.py** (~350 lines):
  - `/health`: Health check endpoint
  - `/inference/analyze_attempt`: Main reasoning analysis endpoint
  - `/questions/{id}`: Fetch question data
  - `/users/{id}/performance`: User stats
  - `/analytics/diagnoses`: Platform-wide analytics
  - Mock reasoning engine (replace with LLM)

### Frontend (Next.js)

- **frontend/pages/index.jsx** (~280 lines):
  - Question Player component
  - Behavioral event tracking (highlights, eliminations, answer changes)
  - Adaptive overlay display (tier-based)
  - Integration with n8n webhook
- **frontend/styles/globals.css**: TailwindCSS base styles
- **frontend/package.json**: Next.js 14, React 18, Tailwind

### Workflow Automation (n8n)

- **n8n/mcat-workflow-simple.json**:
  - 3 nodes: Webhook → HTTP Request (FastAPI) → Respond
  - Path: `/webhook/mcat/submit-answer`
  - No credentials required (easiest to import)
- **n8n/mcat-workflow.json**:
  - 5 nodes: adds conditional logging to Postgres
  - Requires Postgres credentials setup

### CI/CD

- **.github/workflows/ci.yml**:
  - 3 jobs: `lint-and-test`, `frontend-build`, `database-migration-test`
  - Tests FastAPI health, database schema, frontend build
  - Runs on push to main/master/develop/claude/** branches

### Configuration

- **.env.example**: Template for environment variables
- **.gitignore**: Excludes node_modules, .env, database volumes, logs
- **README.md**: Comprehensive documentation (Quick Start, API reference, deployment guide)

## Key Technologies

| Component | Technology | Purpose |
|-----------|------------|---------|
| Frontend | Next.js 14 + React 18 + TailwindCSS | Question Player UI |
| Backend | FastAPI + Python 3.11 | Inference API |
| Database | PostgreSQL 16 + pgvector | Relational + vector storage |
| Cache | Redis 7 | Session state, caching |
| Orchestration | n8n | Workflow automation |
| CI/CD | GitHub Actions | Automated testing |
| Containerization | Docker Compose | Local development |

## Data Flow

```
1. User answers question in frontend (Next.js)
   ↓
2. Frontend sends POST to n8n webhook
   ↓
3. n8n forwards to FastAPI /inference/analyze_attempt
   ↓
4. FastAPI:
   - Fetches question from Postgres
   - Analyzes behavioral events (mock LLM)
   - Generates adaptive overlay based on tier
   - Stores attempt, events, diagnoses in Postgres
   - Caches result in Redis
   ↓
5. FastAPI returns response to n8n
   ↓
6. n8n returns response to frontend
   ↓
7. Frontend displays overlay with diagnoses and drills
```

## Extension Points

### Replace Mock Reasoning with Real LLM

**File**: `fastapi/app/main.py` → `analyze_behavioral_signals()`

- Option A: OpenAI API (gpt-4, gpt-3.5-turbo)
- Option B: Local model (Ollama, vLLM)
- Option C: Hugging Face Inference API

### Add RAG Retrieval

**File**: `fastapi/app/main.py` → Add new function `retrieve_context()`

```python
def retrieve_context(query_embedding):
    query = """
        SELECT stem, passage, explanation
        FROM questions
        ORDER BY passage_embedding <=> %s::vector
        LIMIT 5
    """
    return execute_query(query, (query_embedding,))
```

### Add More Diagnoses

**File**: `fastapi/app/main.py` → `analyze_behavioral_signals()`

Add logic to detect new patterns (e.g., "option paralysis", "anchoring bias")

**File**: `db/migrations/002_add_drills.sql`

Insert corresponding micro-drills for new diagnoses

### Build Analytics Dashboard

**New file**: `frontend/pages/dashboard.jsx`

Fetch data from `/analytics/diagnoses` and `/users/{id}/performance`

## Lines of Code

| Category | Files | Lines |
|----------|-------|-------|
| Database SQL | 1 | ~550 |
| Python (FastAPI) | 1 | ~350 |
| JavaScript (Frontend) | 2 | ~300 |
| Configuration | 7 | ~150 |
| Documentation | 2 | ~800 |
| **Total** | **13** | **~2,150** |

## Next Steps

1. **Run the platform**: `./start.sh`
2. **Import n8n workflow**: Upload `n8n/mcat-workflow-simple.json`
3. **Start frontend**: `cd frontend && npm run dev`
4. **Test end-to-end**: Submit an answer at http://localhost:3000
5. **Replace mock LLM**: Integrate OpenAI or local model
6. **Add more questions**: Insert into `questions` table
7. **Deploy**: Use production Docker Compose + managed Postgres

---

*Generated: 2025-12-07*
