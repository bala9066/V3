#!/bin/bash
# Silicon to Software (S2S) — Production startup (FastAPI only, no --reload, no Streamlit)
# Used by: Docker container (docker-compose.yml)
# For local dev, use start.sh instead.

set -e

echo "================================================"
echo "  ⚡ Silicon to Software (S2S) — AI Hackathon 2026"
echo "  Production Mode"
echo "================================================"

# Validate at least one LLM key is present
if [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$GLM_API_KEY" ] && [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "⚠️  WARNING: No LLM API key found."
    echo "   Set ANTHROPIC_API_KEY, GLM_API_KEY, or DEEPSEEK_API_KEY."
    echo "   The server will start but AI calls will fail."
fi

# Print active LLM
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "✅ LLM: Claude (Anthropic)"
elif [ -n "$DEEPSEEK_API_KEY" ]; then
    echo "✅ LLM: DeepSeek-V3"
elif [ -n "$GLM_API_KEY" ]; then
    echo "✅ LLM: GLM-4 (Z.AI)"
else
    echo "⚠️  LLM: Air-gapped / Ollama fallback only"
fi

# P26 #26 (2026-05-04): honour platform-injected env vars.
#
# Render / Fly / Railway / Heroku all inject $PORT and expect the app
# to bind to it. The previous hard-coded "--port 8000" caused the
# platform health check to time out (Render's load balancer probes
# whatever $PORT resolves to, e.g. 10000, while uvicorn was listening
# on 8000) → every deploy got marked unhealthy and recycled.
#
# WEB_CONCURRENCY: SQLite + multiple uvicorn workers is a known
# footgun — concurrent writes hit `database is locked` even with WAL
# mode, the chroma seed thread races itself, and Base.metadata.create_all
# can race even with the idempotent fix. Default to 1 worker.
# Override via env if you've moved to Postgres + want concurrency.
PORT="${PORT:-8000}"
WEB_CONCURRENCY="${WEB_CONCURRENCY:-1}"

echo ""
echo "Starting FastAPI on http://0.0.0.0:${PORT} ..."
echo "  Workers   : ${WEB_CONCURRENCY}"
echo "  React UI  : http://localhost:${PORT}/app"
echo "  API docs  : http://localhost:${PORT}/docs"
echo "  Health    : http://localhost:${PORT}/health"
echo "================================================"

exec uvicorn main:app \
    --host 0.0.0.0 \
    --port "${PORT}" \
    --workers "${WEB_CONCURRENCY}" \
    --log-level info \
    --access-log
