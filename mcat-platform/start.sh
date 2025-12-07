#!/bin/bash

# MCAT Platform - Quick Start Script
# This script starts all services and performs health checks

set -e

echo "🚀 Starting MCAT Platform..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Start services
echo "📦 Starting Docker services (Postgres, Redis, n8n, FastAPI)..."
docker compose up -d

echo ""
echo "⏳ Waiting for services to initialize (30 seconds)..."
sleep 30

# Health checks
echo ""
echo "🏥 Running health checks..."

# Check Postgres
echo -n "  Postgres... "
if docker exec mcat_postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "     Check logs: docker logs mcat_postgres"
fi

# Check Redis
echo -n "  Redis... "
if docker exec mcat_redis redis-cli ping > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED"
    echo "     Check logs: docker logs mcat_redis"
fi

# Check FastAPI
echo -n "  FastAPI... "
if curl -sSf http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED (may need more time to start)"
    echo "     Check logs: docker logs mcat_fastapi"
fi

# Check n8n
echo -n "  n8n... "
if curl -sSf http://localhost:5678 > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAILED (may need more time to start)"
    echo "     Check logs: docker logs mcat_n8n"
fi

echo ""
echo "✨ Services started!"
echo ""
echo "📍 Access points:"
echo "   FastAPI:     http://localhost:8000"
echo "   FastAPI Docs: http://localhost:8000/docs"
echo "   n8n:         http://localhost:5678"
echo "   Postgres:    localhost:5432 (postgres/postgres)"
echo "   Redis:       localhost:6379"
echo ""
echo "📝 Next steps:"
echo "   1. Import n8n workflow from: n8n/mcat-workflow-simple.json"
echo "   2. Start frontend: cd frontend && npm install && npm run dev"
echo "   3. Open frontend: http://localhost:3000"
echo ""
echo "🛑 To stop services: docker compose down"
echo "🗑️  To remove all data: docker compose down -v"
