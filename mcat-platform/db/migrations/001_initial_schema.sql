-- MCAT Platform Initial Schema Migration
-- This migration creates all tables needed for the MCAT reasoning platform
-- including pgvector support for semantic search and RAG

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgvector";

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    tier VARCHAR(20) DEFAULT 'free' CHECK (tier IN ('free', 'pro', 'premium')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    settings JSONB DEFAULT '{}'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Questions table (MCAT questions with passages)
CREATE TABLE IF NOT EXISTS questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    external_id VARCHAR(100) UNIQUE,  -- e.g., "q-biochem-001"
    category VARCHAR(50) NOT NULL,     -- Biology, Chemistry, Physics, Psychology
    subcategory VARCHAR(100),          -- e.g., "Enzyme Kinetics"
    difficulty INTEGER CHECK (difficulty BETWEEN 1 AND 5),
    stem TEXT NOT NULL,                -- The question text
    passage TEXT,                      -- Associated passage (if any)
    options JSONB NOT NULL,            -- {"A": "text", "B": "text", ...}
    correct_answer VARCHAR(1) NOT NULL CHECK (correct_answer IN ('A', 'B', 'C', 'D')),
    explanation TEXT,
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Vector embeddings for semantic search
    passage_embedding vector(1536),    -- OpenAI ada-002 size; adjust for your model
    stem_embedding vector(1536),
    explanation_embedding vector(1536),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- User attempts (stores each answer submission)
CREATE TABLE IF NOT EXISTS user_attempts (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    selected_option VARCHAR(1) NOT NULL CHECK (selected_option IN ('A', 'B', 'C', 'D')),
    correct BOOLEAN NOT NULL,
    time_taken_ms INTEGER NOT NULL,
    confidence_level INTEGER CHECK (confidence_level BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Store raw behavioral events JSON
    events JSONB DEFAULT '[]'::jsonb,
    -- Inference results
    diagnoses JSONB DEFAULT '[]'::jsonb,
    overlay_shown JSONB,
    drills_assigned JSONB DEFAULT '[]'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Reasoning events (detailed interaction tracking)
CREATE TABLE IF NOT EXISTS reasoning_events (
    id BIGSERIAL PRIMARY KEY,
    attempt_id BIGINT NOT NULL REFERENCES user_attempts(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,   -- 'highlight', 'change_answer', 'eliminate_option', 'pause', etc.
    event_value TEXT,
    timestamp_offset_ms INTEGER NOT NULL, -- ms since attempt start
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Cognitive diagnoses (RPA output)
CREATE TABLE IF NOT EXISTS cognitive_diagnoses (
    id BIGSERIAL PRIMARY KEY,
    attempt_id BIGINT NOT NULL REFERENCES user_attempts(id) ON DELETE CASCADE,
    diagnosis_name VARCHAR(100) NOT NULL,  -- e.g., "premature_closure", "pattern_recognition_kinetics"
    confidence FLOAT CHECK (confidence BETWEEN 0 AND 1),
    explanation TEXT,
    evidence JSONB DEFAULT '{}'::jsonb,     -- Supporting behavioral signals
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Concept nodes (for knowledge graph / RAG retrieval)
CREATE TABLE IF NOT EXISTS concept_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    concept_name VARCHAR(200) UNIQUE NOT NULL,
    category VARCHAR(50),
    description TEXT,
    examples TEXT[],
    related_concepts TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Vector embedding for semantic retrieval
    embedding vector(1536),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Reasoning prompts (for LLM inference)
CREATE TABLE IF NOT EXISTS reasoning_prompts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prompt_name VARCHAR(100) UNIQUE NOT NULL,
    prompt_template TEXT NOT NULL,
    category VARCHAR(50),               -- e.g., "diagnosis", "overlay_generation", "drill_creation"
    tier_required VARCHAR(20) DEFAULT 'free',
    active BOOLEAN DEFAULT TRUE,
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Micro-drills (targeted practice problems)
CREATE TABLE IF NOT EXISTS micro_drills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    diagnosis_name VARCHAR(100) NOT NULL,  -- Links to cognitive_diagnoses
    drill_prompt TEXT NOT NULL,
    drill_answer TEXT,
    difficulty INTEGER CHECK (difficulty BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- User drill completions
CREATE TABLE IF NOT EXISTS user_drill_completions (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    drill_id UUID NOT NULL REFERENCES micro_drills(id) ON DELETE CASCADE,
    attempt_id BIGINT REFERENCES user_attempts(id) ON DELETE SET NULL,
    user_response TEXT,
    correct BOOLEAN,
    time_taken_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- User attempts indexes
CREATE INDEX idx_user_attempts_user_id ON user_attempts(user_id);
CREATE INDEX idx_user_attempts_question_id ON user_attempts(question_id);
CREATE INDEX idx_user_attempts_created_at ON user_attempts(created_at DESC);
CREATE INDEX idx_user_attempts_correct ON user_attempts(correct);

-- Reasoning events indexes
CREATE INDEX idx_reasoning_events_attempt_id ON reasoning_events(attempt_id);
CREATE INDEX idx_reasoning_events_type ON reasoning_events(event_type);

-- Cognitive diagnoses indexes
CREATE INDEX idx_cognitive_diagnoses_attempt_id ON cognitive_diagnoses(attempt_id);
CREATE INDEX idx_cognitive_diagnoses_name ON cognitive_diagnoses(diagnosis_name);

-- Questions indexes
CREATE INDEX idx_questions_category ON questions(category);
CREATE INDEX idx_questions_difficulty ON questions(difficulty);
CREATE INDEX idx_questions_external_id ON questions(external_id);

-- Vector similarity search indexes (HNSW for performance)
CREATE INDEX idx_questions_passage_embedding ON questions USING hnsw (passage_embedding vector_cosine_ops);
CREATE INDEX idx_questions_stem_embedding ON questions USING hnsw (stem_embedding vector_cosine_ops);
CREATE INDEX idx_concept_nodes_embedding ON concept_nodes USING hnsw (embedding vector_cosine_ops);

-- GIN indexes for JSONB fields
CREATE INDEX idx_user_attempts_diagnoses ON user_attempts USING gin (diagnoses);
CREATE INDEX idx_user_attempts_events ON user_attempts USING gin (events);
CREATE INDEX idx_questions_metadata ON questions USING gin (metadata);

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_questions_updated_at BEFORE UPDATE ON questions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_concept_nodes_updated_at BEFORE UPDATE ON concept_nodes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Insert sample users
INSERT INTO users (email, username, tier) VALUES
    ('demo@example.com', 'demo_user', 'free'),
    ('pro@example.com', 'pro_user', 'pro'),
    ('premium@example.com', 'premium_user', 'premium')
ON CONFLICT (email) DO NOTHING;

-- Insert sample question (enzyme kinetics example)
INSERT INTO questions (
    external_id,
    category,
    subcategory,
    difficulty,
    stem,
    passage,
    options,
    correct_answer,
    explanation,
    tags
) VALUES (
    'q-biochem-001',
    'Biochemistry',
    'Enzyme Kinetics',
    3,
    'A researcher adds a competitive inhibitor to an enzyme assay. Which kinetic parameter will increase?',
    'Competitive inhibitors bind to the active site of an enzyme, preventing substrate binding. They can be overcome by increasing substrate concentration. The Michaelis-Menten equation describes the relationship between substrate concentration and reaction velocity.',
    '{"A": "Vmax", "B": "Km (apparent)", "C": "kcat", "D": "Enzyme concentration"}'::jsonb,
    'B',
    'Competitive inhibitors increase the apparent Km because more substrate is needed to reach half-maximal velocity. Vmax remains unchanged because at saturating substrate concentrations, the inhibitor can be outcompeted.',
    ARRAY['enzyme_kinetics', 'competitive_inhibition', 'michaelis_menten']
) ON CONFLICT (external_id) DO NOTHING;

-- Insert sample concept nodes
INSERT INTO concept_nodes (concept_name, category, description, examples) VALUES
    (
        'Competitive Inhibition',
        'Biochemistry',
        'A type of enzyme inhibition where the inhibitor competes with the substrate for binding to the active site. Increases apparent Km but does not affect Vmax.',
        ARRAY['Malonate inhibiting succinate dehydrogenase', 'Methotrexate inhibiting DHFR']
    ),
    (
        'Non-competitive Inhibition',
        'Biochemistry',
        'Inhibitor binds to a site other than the active site, reducing enzyme activity. Decreases Vmax but does not affect Km.',
        ARRAY['Heavy metals inhibiting enzymes', 'Allosteric inhibition']
    )
ON CONFLICT (concept_name) DO NOTHING;

-- Insert sample reasoning prompts
INSERT INTO reasoning_prompts (prompt_name, prompt_template, category, tier_required) VALUES
    (
        'analyze_behavioral_signals',
        'Given the following user interaction events: {events}, identify cognitive patterns and reasoning errors. Focus on: answer changes, elimination patterns, highlighting behavior, and time distribution.',
        'diagnosis',
        'free'
    ),
    (
        'generate_overlay_premium',
        'Based on diagnosis: {diagnosis}, create a detailed reasoning overlay that: 1) Maps the specific error pattern to the question structure, 2) Provides step-by-step correction guidance, 3) Highlights the manipulated variable and control. User tier: premium.',
        'overlay_generation',
        'premium'
    )
ON CONFLICT (prompt_name) DO NOTHING;

-- Insert sample micro-drills
INSERT INTO micro_drills (diagnosis_name, drill_prompt, drill_answer, difficulty) VALUES
    (
        'pattern_recognition_kinetics',
        'If a competitive inhibitor is added to an enzyme-catalyzed reaction, what happens to Km and Vmax?',
        'Km increases (apparent), Vmax remains unchanged.',
        2
    ),
    (
        'premature_closure',
        'Before selecting an answer, list the manipulated variable and the measured outcome in this experiment: "Enzyme activity was measured at pH 4, 7, and 10."',
        'Manipulated: pH. Measured: enzyme activity.',
        1
    )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- VIEWS (for analytics / dashboards)
-- ============================================================================

-- User performance summary view
CREATE OR REPLACE VIEW user_performance_summary AS
SELECT
    u.id AS user_id,
    u.username,
    u.tier,
    COUNT(ua.id) AS total_attempts,
    SUM(CASE WHEN ua.correct THEN 1 ELSE 0 END) AS correct_count,
    ROUND(100.0 * SUM(CASE WHEN ua.correct THEN 1 ELSE 0 END) / NULLIF(COUNT(ua.id), 0), 2) AS accuracy_pct,
    AVG(ua.time_taken_ms) AS avg_time_ms,
    MAX(ua.created_at) AS last_attempt_at
FROM users u
LEFT JOIN user_attempts ua ON u.id = ua.user_id
GROUP BY u.id, u.username, u.tier;

-- Common diagnoses view
CREATE OR REPLACE VIEW common_diagnoses AS
SELECT
    cd.diagnosis_name,
    COUNT(*) AS occurrence_count,
    AVG(cd.confidence) AS avg_confidence,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ua.correct = FALSE THEN cd.attempt_id END) / NULLIF(COUNT(DISTINCT cd.attempt_id), 0), 2) AS incorrect_rate_pct
FROM cognitive_diagnoses cd
LEFT JOIN user_attempts ua ON cd.attempt_id = ua.id
GROUP BY cd.diagnosis_name
ORDER BY occurrence_count DESC;

-- ============================================================================
-- GRANTS (adjust based on your application user)
-- ============================================================================

-- Example: grant to 'mcat_app' user (create this user separately if needed)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mcat_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mcat_app;

-- ============================================================================
-- COMMENTS (for documentation)
-- ============================================================================

COMMENT ON TABLE users IS 'Application users with tier-based access levels';
COMMENT ON TABLE questions IS 'MCAT questions with passages, embeddings, and metadata';
COMMENT ON TABLE user_attempts IS 'Each answer submission with behavioral events and inference results';
COMMENT ON TABLE reasoning_events IS 'Granular interaction tracking (highlights, eliminations, pauses)';
COMMENT ON TABLE cognitive_diagnoses IS 'AI-generated diagnoses of reasoning patterns';
COMMENT ON TABLE concept_nodes IS 'Knowledge graph nodes for RAG retrieval';
COMMENT ON TABLE reasoning_prompts IS 'LLM prompt templates for different inference tasks';
COMMENT ON TABLE micro_drills IS 'Targeted practice problems for specific diagnoses';

COMMENT ON COLUMN questions.passage_embedding IS 'Vector embedding of passage for semantic search (dimension: 1536 for OpenAI ada-002)';
COMMENT ON COLUMN questions.stem_embedding IS 'Vector embedding of question stem';
COMMENT ON COLUMN user_attempts.events IS 'Array of behavioral events: [{"type": "highlight", "value": "inhibitor", "offset_ms": 1200}, ...]';
COMMENT ON COLUMN user_attempts.diagnoses IS 'AI inference results: [{"name": "premature_closure", "confidence": 0.8, "explanation": "..."}]';
