"""
Blue/Green Traffic Router
Proxies requests to app-blue or app-green based on configurable weight.
Access on port 85.
"""

from flask import Flask, request, Response, jsonify
import requests
import threading
import os
import random
import time
from datetime import datetime

app = Flask(__name__)

BLUE_URL  = os.environ.get("BLUE_URL",  "http://app-blue:80")
GREEN_URL = os.environ.get("GREEN_URL", "http://app-green:80")

# State
blue_weight  = 100   # % of traffic going to blue (0 = all green, 100 = all blue)
counts       = {"blue": 0, "green": 0}
latency      = {"blue": [], "green": []}   # last 20 response times each
lock         = threading.Lock()
deploy_log   = []    # history of weight changes

SKIP_HEADERS = {"host", "content-length", "transfer-encoding", "content-encoding"}


def avg_latency(color):
    vals = latency[color][-20:]
    return round(sum(vals) / len(vals), 1) if vals else 0


# ── Router control endpoints ───────────────────────────────────────────────────
@app.route("/router/weight", methods=["GET"])
def get_weight():
    return jsonify({
        "blue":         blue_weight,
        "green":        100 - blue_weight,
        "counts":       counts,
        "avg_latency":  {"blue": avg_latency("blue"), "green": avg_latency("green")},
        "deploy_log":   deploy_log[-10:],
    })


@app.route("/router/weight", methods=["POST"])
def set_weight():
    global blue_weight
    data = request.get_json(silent=True) or {}
    old  = blue_weight
    blue_weight = max(0, min(100, int(data.get("blue", 50))))
    entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "from":      {"blue": old,         "green": 100 - old},
        "to":        {"blue": blue_weight,  "green": 100 - blue_weight},
        "message":   data.get("message", "Manual weight change"),
    }
    deploy_log.append(entry)
    return jsonify({"blue": blue_weight, "green": 100 - blue_weight, "log": entry})


@app.route("/router/reset", methods=["POST"])
def reset_counts():
    with lock:
        counts["blue"] = counts["green"] = 0
        latency["blue"].clear()
        latency["green"].clear()
    return jsonify({"status": "reset"})


# ── Health check for the router itself ────────────────────────────────────────
@app.route("/router/health")
def health():
    return jsonify({"status": "healthy", "blue_weight": blue_weight})


# ── Proxy all other requests ───────────────────────────────────────────────────
@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def proxy(path):
    color  = "blue" if random.randint(1, 100) <= blue_weight else "green"
    target = BLUE_URL if color == "blue" else GREEN_URL

    with lock:
        counts[color] += 1

    headers = {k: v for k, v in request.headers if k.lower() not in SKIP_HEADERS}

    start = time.time()
    try:
        resp = requests.request(
            method  = request.method,
            url     = f"{target}/{path}",
            headers = headers,
            data    = request.get_data(),
            params  = request.args,
            allow_redirects = False,
            timeout = 10,
        )
        ms = round((time.time() - start) * 1000, 1)
        with lock:
            latency[color].append(ms)
            if len(latency[color]) > 100:
                latency[color] = latency[color][-100:]

        out_headers = {k: v for k, v in resp.headers.items()
                       if k.lower() not in SKIP_HEADERS}
        out_headers["X-Routed-To"]      = color
        out_headers["X-Response-Time"]  = f"{ms}ms"
        return Response(resp.content, resp.status_code, out_headers)

    except requests.exceptions.ConnectionError:
        # If target is down, try the other side
        fallback       = GREEN_URL if color == "blue" else BLUE_URL
        fallback_color = "green"   if color == "blue" else "blue"
        try:
            resp = requests.request(
                method  = request.method,
                url     = f"{fallback}/{path}",
                headers = headers,
                data    = request.get_data(),
                params  = request.args,
                allow_redirects = False,
                timeout = 10,
            )
            out_headers = {k: v for k, v in resp.headers.items()
                           if k.lower() not in SKIP_HEADERS}
            out_headers["X-Routed-To"]  = f"{fallback_color} (fallback)"
            return Response(resp.content, resp.status_code, out_headers)
        except Exception as e:
            return jsonify({"error": "Both blue and green are unreachable", "detail": str(e)}), 502

    except Exception as e:
        return jsonify({"error": str(e), "routed_to": color}), 502


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=85, threaded=True)
