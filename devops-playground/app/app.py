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
active_alerts   = []             # populated by Alertmanager webhook


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


@app.route("/guide")
def guide():
    return render_template("guide.html")


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
#  Service Health Board – checks every container in the stack
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/services/health")
def services_health():
    import urllib.request as ur
    services = [
        {"name": "App (self)",   "url": "http://localhost:80/health",      "icon": "⚙️"},
        {"name": "Nginx LB",     "url": "http://nginx:80",                 "icon": "🔀"},
        {"name": "Prometheus",   "url": "http://prometheus:9090/-/healthy","icon": "📊"},
        {"name": "Grafana",      "url": "http://grafana:3000/api/health",  "icon": "📈"},
        {"name": "Alertmanager", "url": "http://alertmanager:9093/-/healthy","icon":"🚨"},
        {"name": "Loki",         "url": "http://loki:3100/ready",          "icon": "📋"},
        {"name": "Router",       "url": "http://router:85/router/health",  "icon": "🔵"},
    ]
    results = []
    for svc in services:
        t0 = time.time()
        try:
            resp = ur.urlopen(svc["url"], timeout=2)
            ms   = round((time.time() - t0) * 1000, 1)
            results.append({**svc, "status": "healthy", "response_ms": ms, "code": resp.status})
        except Exception as e:
            ms = round((time.time() - t0) * 1000, 1)
            results.append({**svc, "status": "unhealthy", "response_ms": ms, "error": str(e)[:60]})
    return jsonify(results)


# ══════════════════════════════════════════════════════════════════════════════
#  Pod Visualizer – real pods from Prometheus, falls back to self
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/pods")
def pods():
    import urllib.request as ur
    try:
        url  = "http://prometheus:9090/api/v1/query?query=app_cpu_usage_percent"
        resp = ur.urlopen(url, timeout=2)
        data = json.loads(resp.read())
        pods_list = [
            {
                "pod_name": r["metric"].get("pod", f"pod-{i}"),
                "cpu":      round(float(r["value"][1]), 1),
                "source":   "prometheus",
            }
            for i, r in enumerate(data.get("data", {}).get("result", []))
        ]
        if pods_list:
            return jsonify({"pods": pods_list, "count": len(pods_list), "source": "prometheus"})
    except Exception:
        pass

    return jsonify({
        "pods": [{
            "pod_name": os.environ.get("POD_NAME", socket.gethostname()),
            "cpu":      psutil.cpu_percent(interval=0.1),
            "source":   "self",
        }],
        "count": 1,
        "source": "self",
    })


# ══════════════════════════════════════════════════════════════════════════════
#  Blue/Green – proxy calls to the router service
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/bluegreen/status")
def bluegreen_status():
    import urllib.request as ur
    try:
        resp = ur.urlopen("http://router:85/router/weight", timeout=2)
        return Response(resp.read(), mimetype="application/json")
    except Exception:
        return jsonify({"blue": 100, "green": 0,
                        "counts": {"blue": 0, "green": 0},
                        "avg_latency": {"blue": 0, "green": 0},
                        "error": "Router not reachable"})


@app.route("/bluegreen/weight", methods=["POST"])
def bluegreen_weight():
    import urllib.request as ur
    try:
        body = json.dumps(request.get_json(silent=True) or {}).encode()
        req  = ur.Request(
            "http://router:85/router/weight", data=body,
            headers={"Content-Type": "application/json"}, method="POST"
        )
        resp = ur.urlopen(req, timeout=2)
        return Response(resp.read(), mimetype="application/json")
    except Exception as e:
        return jsonify({"error": str(e)}), 503


# ══════════════════════════════════════════════════════════════════════════════
#  Alertmanager webhook receiver
# ══════════════════════════════════════════════════════════════════════════════
@app.route("/alerts", methods=["POST"])
def receive_alerts():
    global active_alerts
    data = request.get_json(silent=True) or {}
    alerts = data.get("alerts", [])
    active_alerts = [
        {
            "name":       a.get("labels", {}).get("alertname", "Unknown"),
            "severity":   a.get("labels", {}).get("severity", "info"),
            "status":     a.get("status", "firing"),
            "summary":    a.get("annotations", {}).get("summary", ""),
            "starts_at":  a.get("startsAt", ""),
        }
        for a in alerts
    ]
    logger.info("Alertmanager webhook: %d alert(s) received", len(alerts))
    return jsonify({"status": "ok", "received": len(alerts)})


@app.route("/alerts/list")
def list_alerts():
    return jsonify(active_alerts)


# ══════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=False, threaded=True)
