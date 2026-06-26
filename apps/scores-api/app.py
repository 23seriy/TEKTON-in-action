"""
NBA Scores API — the service we build and deploy with Tekton Pipelines.

VERSION is toggled at build time via Docker build-arg so the same source
produces v1 (basic box scores) and v2 (box scores + play-by-play).
"""

import os
import time
import json
from flask import Flask, jsonify, request

app = Flask(__name__)

VERSION = os.getenv("APP_VERSION", "v1")
BUILD_ID = os.getenv("BUILD_ID", "local")

# ---------------------------------------------------------------------------
# Sample NBA data
# ---------------------------------------------------------------------------
LIVE_GAMES = [
    {
        "game_id": "2025-nba-001",
        "home": {"team": "Lakers", "abbreviation": "LAL", "score": 108},
        "away": {"team": "Celtics", "abbreviation": "BOS", "score": 112},
        "quarter": 4,
        "time_remaining": "2:34",
        "arena": "Crypto.com Arena",
    },
    {
        "game_id": "2025-nba-002",
        "home": {"team": "Warriors", "abbreviation": "GSW", "score": 96},
        "away": {"team": "Nuggets", "abbreviation": "DEN", "score": 101},
        "quarter": 3,
        "time_remaining": "5:12",
        "arena": "Chase Center",
    },
    {
        "game_id": "2025-nba-003",
        "home": {"team": "Bucks", "abbreviation": "MIL", "score": 115},
        "away": {"team": "76ers", "abbreviation": "PHI", "score": 110},
        "quarter": 4,
        "time_remaining": "0:45",
        "arena": "Fiserv Forum",
    },
]

PLAY_BY_PLAY = {
    "2025-nba-001": [
        {"time": "2:34 Q4", "team": "BOS", "player": "Jayson Tatum", "action": "3-point jumper", "score": "112-108"},
        {"time": "2:58 Q4", "team": "LAL", "player": "LeBron James", "action": "driving layup", "score": "108-109"},
        {"time": "3:15 Q4", "team": "BOS", "player": "Jaylen Brown", "action": "steal and fast-break dunk", "score": "109-106"},
    ],
    "2025-nba-002": [
        {"time": "5:12 Q3", "team": "DEN", "player": "Nikola Jokić", "action": "no-look pass to Murray for three", "score": "101-96"},
        {"time": "5:30 Q3", "team": "GSW", "player": "Stephen Curry", "action": "deep three from the logo", "score": "96-98"},
    ],
    "2025-nba-003": [
        {"time": "0:45 Q4", "team": "MIL", "player": "Giannis Antetokounmpo", "action": "euro-step and-one", "score": "115-110"},
        {"time": "1:10 Q4", "team": "PHI", "player": "Joel Embiid", "action": "fadeaway jumper", "score": "112-110"},
    ],
}

TEAM_COLORS = {
    "LAL": {"primary": "#552583", "secondary": "#FDB927"},
    "BOS": {"primary": "#007A33", "secondary": "#BA9653"},
    "GSW": {"primary": "#1D428A", "secondary": "#FFC72C"},
    "DEN": {"primary": "#0E2240", "secondary": "#FEC524"},
    "MIL": {"primary": "#00471B", "secondary": "#EEE1C6"},
    "PHI": {"primary": "#006BB6", "secondary": "#ED174C"},
}


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.route("/")
def index():
    """NBA Scores Dashboard showing version, build info, and live scores."""
    v_color = "#3b82f6" if VERSION == "v1" else "#22c55e"
    v_label = "STABLE" if VERSION == "v1" else "NEW BUILD"
    features = "Basic box scores" if VERSION == "v1" else "Box scores + live play-by-play"

    game_cards = ""
    for game in LIVE_GAMES:
        h = game["home"]
        a = game["away"]
        hc = TEAM_COLORS.get(h["abbreviation"], {"primary": "#333", "secondary": "#888"})
        ac = TEAM_COLORS.get(a["abbreviation"], {"primary": "#333", "secondary": "#888"})
        pbp_html = ""
        if VERSION == "v2":
            plays = PLAY_BY_PLAY.get(game["game_id"], [])
            if plays:
                rows = "".join(
                    f'<div style="display:flex;gap:8px;padding:4px 0;font-size:0.8rem;border-bottom:1px solid rgba(148,163,184,0.06)">'
                    f'<span style="color:#64748b;font-family:monospace;min-width:70px">{p["time"]}</span>'
                    f'<span style="font-weight:800;min-width:35px;color:{TEAM_COLORS.get(p["team"],{"secondary":"#ccc"})["secondary"]}">{p["team"]}</span>'
                    f'<span style="color:#cbd5e1"><strong>{p["player"]}</strong> — {p["action"]}</span>'
                    f'</div>'
                    for p in plays
                )
                pbp_html = f'<div style="margin-top:12px;padding-top:10px;border-top:1px solid rgba(148,163,184,0.1)"><div style="color:#64748b;font-size:0.72rem;font-weight:700;text-transform:uppercase;margin-bottom:6px">PLAY-BY-PLAY <span style="background:#22c55e22;color:#22c55e;padding:1px 6px;border-radius:4px;font-size:0.68rem;border:1px solid #22c55e44;margin-left:6px">v2</span></div>{rows}</div>'

        game_cards += f"""
        <div style="background:linear-gradient(180deg,rgba(30,41,59,0.9),rgba(15,23,42,0.95));border:1px solid rgba(148,163,184,0.12);border-radius:18px;padding:18px;box-shadow:0 12px 32px rgba(0,0,0,0.25)">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px">
            <span style="background:#ef444422;color:#fca5a5;padding:3px 10px;border-radius:999px;font-size:0.78rem;font-weight:700;border:1px solid #ef444433">Q{game["quarter"]} · {game["time_remaining"]}</span>
            <span style="color:#64748b;font-size:0.75rem">{game["arena"]}</span>
          </div>
          <div style="display:flex;align-items:center;justify-content:space-around;gap:8px">
            <div style="text-align:center">
              <div style="font-size:1.4rem;font-weight:900;color:{ac['secondary']}">{a["abbreviation"]}</div>
              <div style="color:#94a3b8;font-size:0.78rem">{a["team"]}</div>
              <div style="font-size:2rem;font-weight:900;margin-top:6px;padding:4px 14px;border-radius:10px;background:rgba(15,23,42,0.6);border-bottom:3px solid {ac['primary']}">{a["score"]}</div>
            </div>
            <div style="color:#475569;font-size:0.8rem;font-weight:700">VS</div>
            <div style="text-align:center">
              <div style="font-size:1.4rem;font-weight:900;color:{hc['secondary']}">{h["abbreviation"]}</div>
              <div style="color:#94a3b8;font-size:0.78rem">{h["team"]}</div>
              <div style="font-size:2rem;font-weight:900;margin-top:6px;padding:4px 14px;border-radius:10px;background:rgba(15,23,42,0.6);border-bottom:3px solid {hc['primary']}">{h["score"]}</div>
            </div>
          </div>
          {pbp_html}
        </div>
        """

    return f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>NBA Scores API {VERSION} — Tekton in Action</title>
<style>*{{box-sizing:border-box;margin:0;padding:0}}body{{font-family:'Segoe UI',system-ui,sans-serif;background:linear-gradient(180deg,#0f172a,#1e293b,#0f172a);color:#f8fafc;min-height:100vh;padding:32px 16px}}.container{{max-width:960px;margin:0 auto}}</style>
</head><body><div class="container">
<div style="background:linear-gradient(135deg,rgba(30,41,59,0.92),rgba(15,23,42,0.95));border:1px solid rgba(148,163,184,0.15);border-radius:24px;padding:28px 32px;box-shadow:0 24px 60px rgba(0,0,0,0.4);margin-bottom:20px">
  <div style="display:flex;align-items:center;gap:14px;margin-bottom:12px">
    <div style="display:inline-flex;align-items:center;gap:8px;padding:6px 16px;border-radius:999px;background:{v_color}22;border:1px solid {v_color}55;font-weight:800;font-size:0.9rem;color:{v_color};text-transform:uppercase">{VERSION} · {v_label}</div>
  </div>
  <h1 style="font-size:2.4rem;background:linear-gradient(135deg,#f97316,#facc15 45%,#38bdf8);-webkit-background-clip:text;-webkit-text-fill-color:transparent;margin-bottom:6px">🏀 NBA Scores API</h1>
  <p style="color:#94a3b8;line-height:1.6">{features} — built and deployed by <strong>Tekton Pipelines</strong>.</p>
  <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-top:18px">
    <div style="background:rgba(15,23,42,0.7);border:1px solid rgba(148,163,184,0.15);border-radius:14px;padding:12px 14px"><div style="color:#64748b;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.06em;font-weight:700">Version</div><div style="margin-top:4px;font-size:1.05rem;font-weight:800;color:{v_color}">{VERSION}</div></div>
    <div style="background:rgba(15,23,42,0.7);border:1px solid rgba(148,163,184,0.15);border-radius:14px;padding:12px 14px"><div style="color:#64748b;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.06em;font-weight:700">Build ID</div><div style="margin-top:4px;font-size:1.05rem;font-weight:800;color:#e2e8f0">{BUILD_ID}</div></div>
    <div style="background:rgba(15,23,42,0.7);border:1px solid rgba(148,163,184,0.15);border-radius:14px;padding:12px 14px"><div style="color:#64748b;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.06em;font-weight:700">Live Games</div><div style="margin-top:4px;font-size:1.05rem;font-weight:800;color:#e2e8f0">{len(LIVE_GAMES)}</div></div>
    <div style="background:rgba(15,23,42,0.7);border:1px solid rgba(148,163,184,0.15);border-radius:14px;padding:12px 14px"><div style="color:#64748b;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.06em;font-weight:700">CI/CD</div><div style="margin-top:4px;font-size:1.05rem;font-weight:800;color:#e2e8f0">Tekton</div></div>
  </div>
</div>
<div style="color:#94a3b8;font-size:0.82rem;font-weight:700;text-transform:uppercase;letter-spacing:0.08em;margin-bottom:10px">Live Scoreboard</div>
<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:14px;margin-bottom:20px">{game_cards}</div>
<div style="color:#475569;font-size:0.82rem;text-align:center;margin-top:8px"><a href="/scores" style="color:#64748b;text-decoration:none">/scores</a> · <a href="/health" style="color:#64748b;text-decoration:none">/health</a> · <a href="/build-info" style="color:#64748b;text-decoration:none">/build-info</a> &nbsp;|&nbsp; Tekton in Action</div>
</div></body></html>"""


@app.route("/scores")
def scores():
    """Return live game scores. v2 adds play-by-play data."""
    games = []
    for game in LIVE_GAMES:
        entry = dict(game)
        if VERSION == "v2":
            entry["play_by_play"] = PLAY_BY_PLAY.get(game["game_id"], [])
        games.append(entry)

    return jsonify({
        "version": VERSION,
        "build_id": BUILD_ID,
        "game_count": len(games),
        "games": games,
    })


@app.route("/health")
def health():
    """Liveness / readiness probe."""
    return jsonify({"status": "healthy", "version": VERSION, "build_id": BUILD_ID})


@app.route("/build-info")
def build_info():
    """Build metadata — shows what Tekton pipeline produced this image."""
    return jsonify({
        "version": VERSION,
        "build_id": BUILD_ID,
        "builder": "Tekton Pipelines",
        "runtime": "Python 3.12 + Flask",
    })


# ---------------------------------------------------------------------------
# Test endpoint for Tekton pipeline verification
# ---------------------------------------------------------------------------
@app.route("/test")
def test():
    """Simple test endpoint for Tekton pipeline test tasks."""
    checks = {
        "scores_endpoint": True,
        "health_endpoint": True,
        "version_set": VERSION in ("v1", "v2"),
        "game_data_loaded": len(LIVE_GAMES) > 0,
    }
    all_pass = all(checks.values())
    return jsonify({
        "status": "PASS" if all_pass else "FAIL",
        "checks": checks,
    }), 200 if all_pass else 500


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
