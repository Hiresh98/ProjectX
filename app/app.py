"""
ProjectX - Sample form-filling application.

Endpoints:
  GET  /            -> HTML form
  POST /submit      -> persists a submission to PostgreSQL, returns JSON
  GET  /api/submissions -> list recent submissions (JSON)
  GET  /healthz     -> liveness probe (always OK if process is up)
  GET  /readyz      -> readiness probe (OK; reports DB status but never fails hard)
  GET  /load        -> CPU-intensive endpoint used to trigger HPA during load testing
                       query params: ms (busy-loop duration, default 200), n (iterations)

The app is deliberately resilient to a missing/unavailable database so that
load testing of the /load endpoint works even before RDS is reachable.
"""
import hashlib
import math
import os
import socket
import time

from flask import Flask, jsonify, request, render_template

app = Flask(__name__)

DB_HOST = os.getenv("DB_HOST", "")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "projectx")
DB_USER = os.getenv("DB_USER", "projectx")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
HOSTNAME = socket.gethostname()

_db_ready = False


def get_conn():
    """Return a new psycopg2 connection or raise. Imported lazily so the app
    can boot even if the DB layer is misconfigured."""
    import psycopg2

    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=3,
    )


def init_db():
    """Create the submissions table if a database is configured."""
    global _db_ready
    if not DB_HOST:
        app.logger.warning("DB_HOST not set; running without a database.")
        return
    try:
        conn = get_conn()
        with conn, conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS submissions (
                    id          SERIAL PRIMARY KEY,
                    name        TEXT NOT NULL,
                    email       TEXT NOT NULL,
                    message     TEXT,
                    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
                );
                """
            )
        conn.close()
        _db_ready = True
        app.logger.info("Database initialized.")
    except Exception as exc:  # noqa: BLE001
        app.logger.error("DB init failed (continuing without DB): %s", exc)


@app.get("/")
def index():
    return render_template("index.html", version=APP_VERSION, host=HOSTNAME)


@app.post("/submit")
def submit():
    # Accept both form-encoded and JSON bodies.
    data = request.get_json(silent=True) or request.form
    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip()
    message = (data.get("message") or "").strip()

    if not name or not email:
        return jsonify(ok=False, error="name and email are required"), 400

    stored = False
    if DB_HOST:
        try:
            conn = get_conn()
            with conn, conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO submissions (name, email, message) VALUES (%s, %s, %s) RETURNING id;",
                    (name, email, message),
                )
                _ = cur.fetchone()[0]
            conn.close()
            stored = True
        except Exception as exc:  # noqa: BLE001
            app.logger.error("Insert failed: %s", exc)

    return jsonify(
        ok=True,
        stored_in_db=stored,
        served_by=HOSTNAME,
        received={"name": name, "email": email, "message": message},
    )


@app.get("/api/submissions")
def list_submissions():
    if not DB_HOST:
        return jsonify(ok=True, db=False, items=[])
    try:
        conn = get_conn()
        with conn, conn.cursor() as cur:
            cur.execute(
                "SELECT id, name, email, message, created_at FROM submissions ORDER BY id DESC LIMIT 50;"
            )
            rows = cur.fetchall()
        conn.close()
        items = [
            {"id": r[0], "name": r[1], "email": r[2], "message": r[3], "created_at": r[4].isoformat()}
            for r in rows
        ]
        return jsonify(ok=True, db=True, items=items)
    except Exception as exc:  # noqa: BLE001
        return jsonify(ok=False, db=True, error=str(exc)), 500


@app.get("/load")
def load():
    """CPU burner to exercise the Horizontal Pod Autoscaler.

    Example: hammer this with a load tester (hey/ab/k6) to push CPU > target
    and watch pods scale from 1 -> 3.
    """
    ms = int(request.args.get("ms", 200))
    deadline = time.time() + (ms / 1000.0)
    x = 0.0001
    iterations = 0
    while time.time() < deadline:
        # Mix of float math + hashing to keep a core busy.
        x = math.sqrt(x * 1.0001 + 1.0001)
        hashlib.sha256(str(x).encode()).hexdigest()
        iterations += 1
    return jsonify(ok=True, served_by=HOSTNAME, busy_ms=ms, iterations=iterations)


@app.get("/healthz")
def healthz():
    return jsonify(status="ok", host=HOSTNAME, version=APP_VERSION)


@app.get("/readyz")
def readyz():
    db_ok = False
    if DB_HOST:
        try:
            conn = get_conn()
            conn.close()
            db_ok = True
        except Exception:  # noqa: BLE001
            db_ok = False
    # Readiness never hard-fails on DB so the app can serve load tests.
    return jsonify(status="ready", db_configured=bool(DB_HOST), db_reachable=db_ok)


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
