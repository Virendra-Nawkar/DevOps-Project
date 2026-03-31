"""
DevOps Playground - Kubernetes Autoscaling Demo App
Demonstrates: HPA scaling, load generation, pod info, health probes,
              metrics, chaos engineering, and more.
"""

from flask import Flask, render_template, jsonify, Response, request
import os
import socket
import time
import threading
import multiprocessing
import psutil
import json
import logging
from datetime import datetime

# ── App setup ──────────────────────────────────────────────────────────────────
app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# ── Global state ───────────────────────────────────────────────────────────────
request_counter = 0
error_counter   = 0
start_time      = time.time()
load_processes  = []
_health_ok      = True           # toggle via /chaos/unhealthy
_ready_ok       = True           # toggle via /chaos/not-ready
_simulate_delay = 0              # artificial latency (ms)
counter_lock    = threading.Lock()


# ── Helper ─────────────────────────────────────────────────────────────────────
def cpu_stress():
    """Infinite CPU burn – runs in a child process."""
    while True:
        _ = 99999 ** 2


def get_pod_info():
    try:
        ip = socket.gethostbyname(socket.gethostname())
    except Exception:
        ip = "unknown"
    return {
        "pod_name":  os.environ.get("POD_NAME",  socket.gethostname()),
        "pod_ip":    os.environ.get("POD_IP",    ip),
        "node_name": os.environ.get("NODE_NAME", "local-machine"),
        "namespace": os.environ.get("NAMESPACE", "default"),
        "app_version": os.environ.get("APP_VERSION", "1.0.0"),
    }


# ── Request hooks ──────────────────────────────────────────────────────────────
@app.before_request
def before_req():
    global request_counter
    with counter_lock:
        request_counter += 1
    if _simulate_delay:
        time.sleep(_simulate_delay / 1000)


# ══════════════════════════════════════════════════════════════════════════════
#  UI
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/")
def index():
    return render_template("index.html")


# ══════════════════════════════════════════════════════════════════════════════
#  Health & readiness probes  (Kubernetes uses these)
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/health")
def health():
    if not _health_ok:
        return jsonify({"status": "unhealthy", "reason": "chaos-injected"}), 500
    return jsonify({"status": "healthy", "timestamp": datetime.utcnow().isoformat()})


@app.route("/ready")
def ready():
    if not _ready_ok:
        return jsonify({"status": "not-ready", "reason": "chaos-injected"}), 503
    return jsonify({"status": "ready"})


# ══════════════════════════════════════════════════════════════════════════════
#  Pod info & real-time metrics
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/info")
def info():
    cpu = psutil.cpu_percent(interval=0.1)
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    return jsonify({
        **get_pod_info(),
        "hostname":          socket.gethostname(),
        "cpu_percent":       cpu,
        "memory_percent":    round(mem.percent, 1),
        "memory_used_mb":    round(mem.used  / 1024 / 1024, 1),
        "memory_total_mb":   round(mem.total / 1024 / 1024, 1),
        "disk_used_gb":      round(disk.used  / 1024**3, 2),
        "disk_total_gb":     round(disk.total / 1024**3, 2),
        "request_count":     request_counter,
        "error_count":       error_counter,
        "uptime_seconds":    round(time.time() - start_time, 1),
        "active_load_workers": len(load_processes),
        "health_ok":         _health_ok,
        "ready_ok":          _ready_ok,
        "simulate_delay_ms": _simulate_delay,
        "timestamp":         datetime.utcnow().isoformat(),
    })


# ══════════════════════════════════════════════════════════════════════════════
#  Prometheus-format metrics endpoint
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/metrics")
def metrics():
    cpu = psutil.cpu_percent(interval=0.1)
    mem = psutil.virtual_memory()
    uptime = time.time() - start_time
    pod = get_pod_info()

    lines = [
        "# HELP app_requests_total Total HTTP requests received",
        "# TYPE app_requests_total counter",
        f'app_requests_total{{pod="{pod["pod_name"]}",namespace="{pod["namespace"]}"}} {request_counter}',

        "# HELP app_errors_total Total errors",
        "# TYPE app_errors_total counter",
        f'app_errors_total{{pod="{pod["pod_name"]}"}} {error_counter}',

        "# HELP app_cpu_usage_percent CPU usage percent",
        "# TYPE app_cpu_usage_percent gauge",
        f'app_cpu_usage_percent{{pod="{pod["pod_name"]}"}} {cpu}',

        "# HELP app_memory_usage_bytes Memory used",
        "# TYPE app_memory_usage_bytes gauge",
        f'app_memory_usage_bytes{{pod="{pod["pod_name"]}"}} {mem.used}',

        "# HELP app_load_workers Active CPU stress workers",
        "# TYPE app_load_workers gauge",
        f'app_load_workers{{pod="{pod["pod_name"]}"}} {len(load_processes)}',

        "# HELP app_uptime_seconds Application uptime",
        "# TYPE app_uptime_seconds gauge",
        f'app_uptime_seconds{{pod="{pod["pod_name"]}"}} {uptime:.2f}',
    ]
    return Response("\n".join(lines) + "\n", mimetype="text/plain")


# ══════════════════════════════════════════════════════════════════════════════
#  Load generation  (triggers HPA CPU-based scaling)
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/load/start", methods=["POST"])
def load_start():
    data = request.get_json(silent=True) or {}
    workers = min(int(data.get("workers", 2)), 8)   # cap at 8
    for _ in range(workers):
        p = multiprocessing.Process(target=cpu_stress, daemon=True)
        p.start()
        load_processes.append(p)
    logger.info("Load started – total workers: %d", len(load_processes))
    return jsonify({
        "status": "load_started",
        "added_workers": workers,
        "total_workers": len(load_processes),
        "message": f"Spawned {workers} CPU workers. Watch HPA scale up!",
    })


@app.route("/load/stop", methods=["POST"])
def load_stop():
    count = len(load_processes)
    for p in load_processes:
        p.terminate()
    load_processes.clear()
    logger.info("Load stopped – terminated %d workers", count)
    return jsonify({
        "status": "load_stopped",
        "terminated_workers": count,
        "message": "All workers stopped. Pods will scale down after cool-down.",
    })


@app.route("/load/status")
def load_status():
    return jsonify({
        "active_workers": len(load_processes),
        "cpu_percent":    psutil.cpu_percent(interval=0.1),
    })


# ══════════════════════════════════════════════════════════════════════════════
#  Chaos Engineering endpoints
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/chaos/unhealthy", methods=["POST"])
def chaos_unhealthy():
    global _health_ok
    _health_ok = False
    logger.warning("CHAOS: liveness probe set to FAIL")
    return jsonify({"status": "liveness_failing", "message": "Pod will be restarted by Kubernetes!"})


@app.route("/chaos/healthy", methods=["POST"])
def chaos_healthy():
    global _health_ok
    _health_ok = True
    return jsonify({"status": "liveness_ok"})


@app.route("/chaos/not-ready", methods=["POST"])
def chaos_not_ready():
    global _ready_ok
    _ready_ok = False
    logger.warning("CHAOS: readiness probe set to FAIL")
    return jsonify({"status": "readiness_failing", "message": "Pod removed from Service endpoints!"})


@app.route("/chaos/ready", methods=["POST"])
def chaos_ready():
    global _ready_ok
    _ready_ok = True
    return jsonify({"status": "readiness_ok"})


@app.route("/chaos/delay", methods=["POST"])
def chaos_delay():
    global _simulate_delay
    data = request.get_json(silent=True) or {}
    ms = max(0, min(int(data.get("ms", 500)), 5000))
    _simulate_delay = ms
    logger.warning("CHAOS: artificial delay set to %d ms", ms)
    return jsonify({"status": "delay_set", "delay_ms": ms})


@app.route("/chaos/error", methods=["GET"])
def chaos_error():
    global error_counter
    with counter_lock:
        error_counter += 1
    return jsonify({"error": "Simulated 500 error for chaos testing"}), 500


# ══════════════════════════════════════════════════════════════════════════════
#  Server-Sent Events – live dashboard updates (no polling needed)
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/stream")
def stream():
    def generate():
        while True:
            try:
                cpu  = psutil.cpu_percent(interval=1)
                mem  = psutil.virtual_memory()
                data = {
                    "cpu":          round(cpu, 1),
                    "memory":       round(mem.percent, 1),
                    "requests":     request_counter,
                    "errors":       error_counter,
                    "workers":      len(load_processes),
                    "health_ok":    _health_ok,
                    "ready_ok":     _ready_ok,
                    "delay_ms":     _simulate_delay,
                    "uptime":       round(time.time() - start_time, 0),
                    "timestamp":    datetime.utcnow().isoformat(),
                }
                yield f"data: {json.dumps(data)}\n\n"
                time.sleep(2)
            except GeneratorExit:
                break

    return Response(
        generate(),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# ══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)
