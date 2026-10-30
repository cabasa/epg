#!/usr/bin/env bash

set -euo pipefail

BASE="$HOME/epg"
WG="$BASE/wg"
LOGDIR="$BASE/logs"

mkdir -p "$LOGDIR"

STABLE_LOG="$LOGDIR/latest-run.log"
LIVE_LOG="$LOGDIR/live.log"

timestamp_utc="$(date -u +'%Y-%m-%d_%H-%M-%S')"
RUN_LOG="$LOGDIR/run-$timestamp_utc.log"

log() {
  echo "$*" | tee -a "$RUN_LOG" "$STABLE_LOG" "$LIVE_LOG"
}

# --- Git: always start from clean origin/main ---

cd "$BASE"

git fetch origin | tee -a "$RUN_LOG" "$STABLE_LOG" "$LIVE_LOG" || true
git checkout main | tee -a "$RUN_LOG" "$STABLE_LOG" "$LIVE_LOG"
git reset --hard origin/main | tee -a "$RUN_LOG" "$STABLE_LOG" "$LIVE_LOG"
git clean -fd | tee -a "$RUN_LOG" "$STABLE_LOG" "$LIVE_LOG"

# Truncate logs after Git reset

: > "$STABLE_LOG"
: > "$LIVE_LOG"
: > "$RUN_LOG"

log "=== Run started: $(date -u) ==="

# --- Prepare WebGrab configuration from GitHub ---

mkdir -p "$WG" "$HOME/.wg++"

# Copy the latest GitHub-managed config into WebGrab's working directory
cp "$BASE/webgrab/WebGrab++.config.xml" "$WG/WebGrab++.config.xml"

# Replace Mac output path with the server output path
python3 - "$WG/WebGrab++.config.xml" "$BASE/epg.xml" <<'PY'
import sys
from pathlib import Path

config = Path(sys.argv[1])
output = sys.argv[2]

text = config.read_text(encoding="utf-8")

import re
text, count = re.subn(
    r"<filename>.*?</filename>",
    f"<filename>{output}</filename>",
    text,
    count=1
)

if count != 1:
    raise SystemExit("ERROR: Could not locate <filename> in WebGrab config")

config.write_text(text, encoding="utf-8")
PY

# Keep existing siteini configuration available
ln -sfn "$BASE/webgrab/WebGrab++.config.xml" "$HOME/.wg++/WebGrab++.config.xml"
ln -sfn "$BASE/webgrab/siteini.pack" "$HOME/.wg++/siteini.pack"

log "Using GitHub configuration: $BASE/webgrab/WebGrab++.config.xml"
log "EPG output: $BASE/epg.xml"

# --- Run WebGrab ---

cd "$WG"

dotnet ./bin.net/WebGrab+Plus.dll . 2>&1 | tee -a "$RUN_LOG" "$STABLE_LOG" "$LIVE_LOG"

log "=== Run finished: $(date -u) ==="

# --- Sanity check ---

if [ ! -s "$BASE/epg.xml" ]; then
  log "ERROR: epg.xml missing or empty at $BASE/epg.xml"
  exit 1
fi

# --- Commit & push result ---

cd "$BASE"

git add epg.xml
git add -f "$LOGDIR/latest-run.log"

if git diff --cached --quiet; then
  log "No changes to commit"
  exit 0
fi

git commit -m "EPG update (server)" | tee -a "$RUN_LOG" "$STABLE_LOG" "$LIVE_LOG"
git push origin main | tee -a "$RUN_LOG" "$STABLE_LOG" "$LIVE_LOG"

log "=== Pushed to GitHub ==="
