# MCAT Reasoning Platform - Full-Stack Starter

[![CI](https://github.com/Str8ZeRO1/n8n-workflows/actions/workflows/ci.yml/badge.svg)](https://github.com/Str8ZeRO1/n8n-workflows/actions)

A **production-ready full-stack starter** for an MCAT test prep platform featuring AI-powered reasoning analysis, adaptive overlays, and micro-drill generation.

## 🎯 Overview

This platform analyzes student reasoning patterns during MCAT practice questions and provides **tier-based adaptive feedback**:

- **Free tier**: Basic overlay with high-level hints
- **Pro tier**: Detailed step-by-step reasoning guidance
- **Premium tier**: Advanced overlays with visual aids and personalized micro-drills

### Key Features

- 🧠 **Reasoning Pattern Analysis (RPA)**: AI-powered detection of cognitive patterns (premature closure, surface reading, etc.)
- 📊 **Behavioral Event Tracking**: Captures highlights, eliminations, answer changes, and timing
- 🎓 **Adaptive Overlays**: Tier-based feedback that maps errors to specific question structure
- 🎯 **Micro-Drills**: Targeted practice problems based on diagnosed weaknesses
- 🔍 **Vector Search**: pgvector-powered semantic retrieval for RAG (Retrieval-Augmented Generation)
- 🔄 **n8n Orchestration**: Workflow automation for inference pipeline

---

## 🏗️ Architecture

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Next.js   │─────▶│     n8n     │─────▶│   FastAPI   │
│  Frontend   │      │  Workflow   │      │  Inference  │
│             │      │ Orchestrator│      │   Service   │
└─────────────┘      └─────────────┘      └─────────────┘
                            │                     │
                            ▼                     ▼
                     ┌─────────────┐      ┌─────────────┐
                     │  Postgres   │      │    Redis    │
                     │  +pgvector  │      │   (Cache)   │
                     └─────────────┘      └─────────────┘
```

### Tech Stack

- **Frontend**: Next.js 14, React 18, TailwindCSS
- **Backend**: FastAPI, Python 3.11
- **Database**: PostgreSQL 16 + pgvector extension
- **Cache**: Redis 7
- **Orchestration**: n8n (workflow automation)
- **CI/CD**: GitHub Actions
- **Deployment**: Docker Compose

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Node.js 18+ (for local frontend development)
- Git

### 1. Clone and Start Services

```bash
# Clone the repository
git clone https://github.com/Str8ZeRO1/n8n-workflows.git
cd n8n-workflows/mcat-platform

# Start all services (Postgres, Redis, n8n, FastAPI)
docker compose up -d

# Check service health
docker compose ps
```

**Wait ~30 seconds** for all services to initialize.

### 2. Verify Services

```bash
# Check FastAPI health
curl http://localhost:8000/health | jq

# Check n8n (open in browser)
open http://localhost:5678
```

Expected output:
```json
{
  "status": "ok",
  "database": "ok",
  "redis": "ok",
  "timestamp": "2025-12-07T..."
}
```

### 3. Import n8n Workflow

1. Open n8n at [http://localhost:5678](http://localhost:5678)
2. Click **Workflows** → **Import from File**
3. Select `n8n/mcat-workflow-simple.json`
4. Click **Activate** to enable the workflow
5. Verify webhook path: `/webhook/mcat/submit-answer`

### 4. Start Frontend

```bash
cd frontend
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

### 5. Test End-to-End Flow

1. On the frontend, read the sample question about enzyme kinetics
2. Use the **Highlight** buttons to mark key terms (tracks behavioral events)
3. Optionally **Eliminate** wrong answers
4. Select an answer (A, B, C, or D)
5. Click **Submit Answer**
6. View the AI-generated overlay with diagnoses and micro-drills

**Flow:**
```
Frontend → n8n webhook → FastAPI /inference/analyze_attempt → DB write → Response with overlay
```

---

## 📊 Database Schema

The PostgreSQL database includes:

- **`users`**: User accounts with tier information
- **`questions`**: MCAT questions with passages and vector embeddings
- **`user_attempts`**: Answer submissions with behavioral events
- **`reasoning_events`**: Granular interaction tracking (highlights, eliminations, etc.)
- **`cognitive_diagnoses`**: AI-generated reasoning pattern diagnoses
- **`concept_nodes`**: Knowledge graph for RAG retrieval
- **`reasoning_prompts`**: LLM prompt templates
- **`micro_drills`**: Targeted practice problems

### Vector Embeddings (pgvector)

The schema supports **semantic search** via pgvector:
- `questions.passage_embedding` (vector dimension: 1536)
- `questions.stem_embedding`
- `concept_nodes.embedding`

**To generate embeddings in production**, integrate OpenAI Embeddings API or a local model (e.g., sentence-transformers).

### Sample Data

The migration includes seed data:
- 3 demo users (free, pro, premium tiers)
- 1 sample question (enzyme kinetics)
- 2 concept nodes (competitive inhibition, non-competitive inhibition)
- 2 micro-drills

---

## 🔧 Configuration

### Environment Variables

Create a `.env` file in `mcat-platform/`:

```bash
# Database
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/mcat

# Redis
REDIS_URL=redis://redis:6379/0

# Optional: OpenAI API (for embeddings/LLM)
OPENAI_API_KEY=sk-...

# Optional: FastAPI settings
PORT=8000
```

### User Tiers

Change the tier in the frontend dropdown to test different overlay levels:

- **Free** (Level 1): 2-3 high-level reasoning steps
- **Pro** (Level 2): 4-5 steps with conceptual hints
- **Premium** (Level 3): 6+ steps with visual aids and detailed explanations

---

## 📡 API Endpoints

### FastAPI Service (`http://localhost:8000`)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API info and available endpoints |
| `/health` | GET | Health check (database, Redis) |
| `/inference/analyze_attempt` | POST | Main inference endpoint |
| `/questions/{question_id}` | GET | Fetch question by ID or external_id |
| `/users/{user_id}/performance` | GET | User performance summary |
| `/analytics/diagnoses` | GET | Common diagnoses across users |

### Example: Analyze Attempt

```bash
curl -X POST http://localhost:8000/inference/analyze_attempt \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "question_id": "q-biochem-001",
    "answer": "B",
    "time_ms": 25000,
    "events": [
      {"type": "highlight", "value": "inhibitor", "timestamp_offset_ms": 3000},
      {"type": "change_answer", "value": "A -> B", "timestamp_offset_ms": 15000}
    ],
    "user_tier": "premium",
    "confidence_level": 4
  }'
```

**Response:**
```json
{
  "correct": true,
  "correct_answer": "B",
  "diagnoses": [
    {
      "name": "pattern_recognition_kinetics",
      "confidence": 0.82,
      "explanation": "Highlighting enzyme kinetics terms indicates awareness...",
      "evidence": {"highlighted_kinetics_terms": true}
    }
  ],
  "overlay": {
    "level": 3,
    "insight": "You recognized enzyme kinetics concepts. Now map them to the specific manipulated variable.",
    "steps": ["Read the question stem...", "Identify the manipulated variable...", ...]
  },
  "drills": [
    {
      "prompt": "What happens to Km when a competitive inhibitor is added?",
      "answer": "Km increases (apparent Km)",
      "difficulty": 2
    }
  ],
  "debug": {"duration_s": 0.142, "attempt_id": 123, "tier": "premium"}
}
```

---

## 🧪 Testing

### Run CI Tests Locally

```bash
# Build and test all services
cd mcat-platform
docker compose up --build

# In another terminal, run health checks
curl http://localhost:8000/health
curl http://localhost:8000/questions/q-biochem-001
```

### Database Verification

```bash
# Connect to Postgres
docker exec -it mcat_postgres psql -U postgres -d mcat

# List tables
\dt

# Check seed data
SELECT * FROM users;
SELECT * FROM questions;
SELECT * FROM user_attempts;

# Verify pgvector extension
SELECT * FROM pg_extension WHERE extname='vector';
```

### Redis Cache Check

```bash
# Connect to Redis
docker exec -it mcat_redis redis-cli

# Check cached data
KEYS user:*
HGETALL user:550e8400-e29b-41d4-a716-446655440000:last_attempt
```

---

## 🎨 Frontend Components

The Next.js frontend includes:

- **Question Player**: Main interface for answering questions
- **Behavioral Event Tracking**: Highlight, eliminate, answer change detection
- **Adaptive Overlay Display**: Renders diagnoses, reasoning steps, and micro-drills
- **Tier Selector**: Switch between free/pro/premium to test overlay levels

### Styling

Built with **TailwindCSS** for responsive, modern UI. Key classes:
- `.card`: White background card with shadow
- `.btn-primary`: Blue CTA button
- `.btn-secondary`: Gray secondary button

---

## 🔄 n8n Workflows

The `n8n/mcat-workflow-simple.json` workflow:

1. **Webhook Trigger**: Receives POST from frontend at `/webhook/mcat/submit-answer`
2. **HTTP Request Node**: Calls FastAPI `/inference/analyze_attempt`
3. **Respond to Webhook**: Returns inference results to frontend

### Import Instructions

1. n8n UI → **Import from File**
2. Select `mcat-workflow-simple.json`
3. Activate workflow
4. Test with cURL or frontend

---

## 🚀 Deployment

### Production Considerations

1. **Security**:
   - Enable n8n basic auth (`N8N_BASIC_AUTH_ACTIVE=true`)
   - Use environment secrets for database credentials
   - Add HTTPS/TLS termination (nginx, Cloudflare)
   - Implement rate limiting (FastAPI middleware or nginx)

2. **Database**:
   - Use managed Postgres (AWS RDS, Supabase, etc.)
   - Set up automated backups
   - Enable connection pooling (pgBouncer)
   - Add read replicas for analytics queries

3. **Caching**:
   - Use Redis persistence (`appendonly yes`)
   - Consider Redis Cluster for high availability

4. **Scaling**:
   - Horizontal scaling: Multiple FastAPI replicas behind load balancer
   - Async database drivers (asyncpg) for better concurrency
   - CDN for frontend static assets (Vercel, Cloudflare Pages)

5. **Monitoring**:
   - Application: Sentry for error tracking
   - Infrastructure: Prometheus + Grafana
   - Logging: ELK stack or Datadog

### Docker Production Build

```bash
# Build optimized images
docker compose -f docker-compose.yml build --no-cache

# Start with resource limits
docker compose up -d --scale fastapi=3
```

---

## 🧠 Extending the Platform

### 1. Replace Mock Reasoning with Real LLM

Current implementation uses **heuristic rules** in `fastapi/app/main.py`. To integrate a real LLM:

**Option A: OpenAI API**
```python
import openai

def analyze_behavioral_signals(events, time_ms):
    prompt = f"Analyze these behavioral events: {events}. Identify reasoning patterns."
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}]
    )
    # Parse response into Diagnosis objects
    return parse_llm_response(response)
```

**Option B: Local Model (Ollama, vLLM)**
```python
import requests

def analyze_behavioral_signals(events, time_ms):
    response = requests.post("http://ollama:11434/api/generate", json={
        "model": "llama3",
        "prompt": f"Analyze: {events}"
    })
    return parse_llm_response(response.json())
```

### 2. Add RAG Retrieval

Use pgvector for semantic search:

```python
def retrieve_similar_passages(query_embedding):
    query = """
        SELECT stem, passage, explanation
        FROM questions
        ORDER BY passage_embedding <=> %s::vector
        LIMIT 5
    """
    return execute_query(query, (query_embedding,))
```

Generate embeddings:
```python
import openai

def get_embedding(text):
    response = openai.Embedding.create(
        model="text-embedding-ada-002",
        input=text
    )
    return response['data'][0]['embedding']
```

### 3. Add More Cognitive Diagnoses

Edit `fastapi/app/main.py` → `analyze_behavioral_signals()`:

```python
# Example: Detect "option paralysis"
if len(eliminate_events) == 0 and time_ms > 60000:
    diagnoses.append(Diagnosis(
        name="option_paralysis",
        confidence=0.75,
        explanation="Long time without eliminations suggests difficulty narrowing choices.",
        evidence={"time_ms": time_ms, "eliminated": 0}
    ))
```

Add corresponding micro-drills to the `micro_drills` table.

### 4. Build Analytics Dashboard

Create a new page in `frontend/pages/dashboard.jsx`:

```jsx
import { useState, useEffect } from 'react';

export default function Dashboard() {
  const [stats, setStats] = useState(null);

  useEffect(() => {
    fetch('http://localhost:8000/analytics/diagnoses')
      .then(res => res.json())
      .then(setStats);
  }, []);

  return (
    <div>
      <h1>Platform Analytics</h1>
      {stats?.map(diag => (
        <div key={diag.diagnosis_name}>
          {diag.diagnosis_name}: {diag.occurrence_count} occurrences
        </div>
      ))}
    </div>
  );
}
```

---

## 📚 Additional Resources

### Database Migrations

To add new migrations:

```bash
# Create new migration file
touch db/migrations/002_add_new_table.sql

# Restart Postgres to apply (development only)
docker compose restart postgres
```

For production, use a migration tool like **Alembic** or **Flyway**.

### n8n Workflow Development

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- Export workflows via n8n UI: **Settings** → **Export**

### Vector Search (pgvector)

- [pgvector GitHub](https://github.com/pgvector/pgvector)
- [Similarity Search Guide](https://github.com/pgvector/pgvector#querying)

---

## 🐛 Troubleshooting

### "Connection refused" when calling FastAPI

**Issue**: Frontend can't reach FastAPI or n8n

**Solution**:
```bash
# Check if services are running
docker compose ps

# Restart services
docker compose restart

# Check logs
docker logs mcat_fastapi
```

### Database migration not applied

**Issue**: Tables not created in Postgres

**Solution**:
```bash
# Remove volumes and restart
docker compose down -v
docker compose up -d

# Manually apply migration
docker exec -i mcat_postgres psql -U postgres -d mcat < db/migrations/001_initial_schema.sql
```

### n8n workflow not triggering

**Issue**: Webhook returns 404

**Solution**:
1. Verify workflow is **Active** (toggle in n8n UI)
2. Check webhook path matches frontend URL
3. Test directly with cURL:
   ```bash
   curl -X POST http://localhost:5678/webhook/mcat/submit-answer \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}'
   ```

### Frontend build errors

**Issue**: `npm run build` fails

**Solution**:
```bash
# Clear cache and reinstall
rm -rf node_modules .next
npm install
npm run build
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-diagnosis`
3. Commit changes: `git commit -m "Add new diagnosis pattern"`
4. Push: `git push origin feature/new-diagnosis`
5. Open a Pull Request

### Development Setup

```bash
# Install pre-commit hooks (optional)
pip install pre-commit
pre-commit install

# Run tests
cd fastapi
pytest

# Lint Python code
black app/ --check
ruff app/
```

---

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.

---

## 🙏 Acknowledgments

- **n8n** - Workflow automation platform
- **pgvector** - Vector similarity search for Postgres
- **FastAPI** - Modern Python web framework
- **Next.js** - React framework for production

---

## 📞 Support

For questions or issues:

- Open an [issue](https://github.com/Str8ZeRO1/n8n-workflows/issues)
- Discussion forum: [GitHub Discussions](https://github.com/Str8ZeRO1/n8n-workflows/discussions)

---

**Built with ❤️ for MCAT test prep innovation**

*Last updated: December 2025*
