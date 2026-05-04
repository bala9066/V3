FROM python:3.12-slim

WORKDIR /app

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pandoc \
    graphviz \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies first (better layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# P26 #24 (2026-05-04): removed `playwright install chromium` step.
# Playwright is NOT in requirements.txt (pip install fails with "command
# not found"), and the only consumer is `tests/test_ui_playwright.py`
# which uses `pytest.importorskip` — production runtime never touches a
# headless browser. Mermaid renders via mmdc (Node) + the shared
# `_render_mermaid_local` chain. Including Chromium would have added
# ~300 MB to the image for zero production benefit.

# Copy application code
COPY . .

# Create required directories
RUN mkdir -p output chroma_data logs

# Non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Health check — FastAPI. Uses ${PORT:-8000} so the in-container
# health check matches what start-prod.sh actually binds to (Render /
# Fly / Railway inject $PORT). start-period bumped to 60s because the
# chromadb daemon thread + opentelemetry instrumentation extend cold
# startup past 30s on small instances.
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f "http://localhost:${PORT:-8000}/health" || exit 1

EXPOSE 8000

CMD ["sh", "start-prod.sh"]
