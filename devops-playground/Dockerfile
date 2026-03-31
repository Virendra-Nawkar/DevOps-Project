# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 – Builder
#   Install Python deps into a virtual-env so Stage 2 stays lean
# ─────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build tools (needed for psutil C extension)
RUN apt-get update && apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 – Runtime  (lean final image)
# ─────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

LABEL maintainer="devops-playground"
LABEL description="DevOps Playground – Kubernetes autoscaling demo app"
LABEL version="1.0.0"

# Security: run as non-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy venv from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application source
COPY app/ .

# Kubernetes will inject these via Downward API (see deployment.yaml)
ENV POD_NAME=""
ENV POD_IP=""
ENV NODE_NAME=""
ENV NAMESPACE="default"
ENV APP_VERSION="1.0.0"

# Flask / Gunicorn config
ENV FLASK_ENV=production
ENV GUNICORN_WORKERS=2
ENV GUNICORN_THREADS=4

# Non-privileged port
EXPOSE 5000

USER appuser

# Health-check so Docker (and docker-compose) can see pod health too
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

# Gunicorn serves the Flask app
CMD ["gunicorn", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "2", \
     "--threads", "4", \
     "--timeout", "120", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]
