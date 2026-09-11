from flask import Flask, render_template, request, make_response, g
from redis import Redis
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
import os
import socket
import random
import json
import logging

# ──────────────────────────────────────────────────────────
# Logging — structured JSON so Promtail can parse fields
# ──────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s", "logger": "%(name)s"}',
)
logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────────────────
# OpenTelemetry Tracing
# ──────────────────────────────────────────────────────────
OTEL_ENDPOINT = os.getenv(
    "OTEL_EXPORTER_OTLP_ENDPOINT",
    "http://otel-collector.ns-observability.svc.cluster.local:4317",
)

resource = Resource.create({
    "service.name": "vote-app",
    "service.version": "1.0.0",
    "deployment.environment": os.getenv("ENV", "prd"),
})

tracer_provider = TracerProvider(resource=resource)
otlp_exporter = OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True)
tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(tracer_provider)
tracer = trace.get_tracer(__name__)

# ──────────────────────────────────────────────────────────
# Prometheus Metrics
# ──────────────────────────────────────────────────────────
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "status", "service"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "service"],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)
VOTE_COUNTER = Counter(
    "votes_total",
    "Total votes cast",
    ["option"],
)

# ──────────────────────────────────────────────────────────
# Application
# ──────────────────────────────────────────────────────────
option_a = os.getenv("OPTION_A", "Cats")
option_b = os.getenv("OPTION_B", "Dogs")
hostname = socket.gethostname()

app = Flask(__name__)

# Auto-instrument Flask (traces every request)
FlaskInstrumentor().instrument_app(app)
# Auto-instrument Redis client
RedisInstrumentor().instrument()

gunicorn_error_logger = logging.getLogger("gunicorn.error")
app.logger.handlers.extend(gunicorn_error_logger.handlers)
app.logger.setLevel(logging.INFO)


def get_redis():
    if not hasattr(g, "redis"):
        g.redis = Redis(
            host=os.getenv("REDIS_HOST", "redis"),
            db=0,
            socket_timeout=5,
        )
    return g.redis


@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint."""
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


@app.route("/healthz")
def healthz():
    """Liveness probe."""
    return {"status": "ok"}, 200


@app.route("/", methods=["POST", "GET"])
def hello():
    import time
    start = time.time()

    voter_id = request.cookies.get("voter_id")
    if not voter_id:
        voter_id = hex(random.getrandbits(64))[2:-1]

    vote = None

    try:
        if request.method == "POST":
            redis = get_redis()
            vote = request.form["vote"]

            with tracer.start_as_current_span("cast-vote") as span:
                span.set_attribute("vote.option", vote)
                span.set_attribute("voter.id", voter_id)

                data = json.dumps({"voter_id": voter_id, "vote": vote})
                redis.rpush("votes", data)

                VOTE_COUNTER.labels(option=vote).inc()
                logger.info(
                    '{"message": "Vote cast", "voter_id": "%s", "vote": "%s", "trace_id": "%s"}',
                    voter_id, vote,
                    format(trace.get_current_span().get_span_context().trace_id, "032x"),
                )

        REQUEST_COUNT.labels(method=request.method, status="200", service="vote-app").inc()
    except Exception as exc:
        REQUEST_COUNT.labels(method=request.method, status="500", service="vote-app").inc()
        logger.error('{"message": "Request failed", "error": "%s"}', str(exc))
        raise
    finally:
        REQUEST_LATENCY.labels(method=request.method, service="vote-app").observe(
            time.time() - start
        )

    resp = make_response(
        render_template(
            "index.html",
            option_a=option_a,
            option_b=option_b,
            hostname=hostname,
            vote=vote,
        )
    )
    resp.set_cookie("voter_id", voter_id)
    return resp


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True, threaded=True)
