#!/usr/bin/env bash
# context-pilot sampling layer: PostToolUse hook (matcher "*").
#
# Watches how full the context window is and, past a threshold, injects a
# [context-pilot] alert asking the model to evaluate the boundary using the
# context-pilot skill's decision rule (t / H / N). Everything that is not an
# injection is a silent exit 0 — this hook must never slow down or break
# normal tool flow.
#
# Context size is read from the session's own transcript JSONL: the latest
# assistant message's usage block (input_tokens + cache read/creation) is the
# cumulative context the next turn will carry. Cheap by construction: only the
# transcript tail is parsed, and a per-session throttle skips the parse
# entirely between checks.
#
# Config (~/.claude/context-pilot/config.json, all optional):
#   context_window     total window in tokens        (default 200000)
#   warn_pct           inject threshold, percent     (default 70)
#   cooldown_minutes   min gap between alerts        (default 15)
#   check_seconds      min gap between transcript    (default 60)
#                      parses
#
# Env overrides (tests):
#   CONTEXT_PILOT_DIR  state dir (default ~/.claude/context-pilot)

set -uo pipefail

PAYLOAD="$(cat 2>/dev/null || true)"
CP_DIR="${CONTEXT_PILOT_DIR:-$HOME/.claude/context-pilot}"
mkdir -p "$CP_DIR" 2>/dev/null || true

PAYLOAD="$PAYLOAD" CP_DIR="$CP_DIR" python3 <<'PY'
import json, os, sys, time

cp_dir = os.environ["CP_DIR"]
try:
    payload = json.loads(os.environ.get("PAYLOAD") or "{}")
except Exception:
    payload = {}

transcript = payload.get("transcript_path") or ""
session_id = payload.get("session_id") or "unknown"
if not transcript or not os.path.isfile(transcript):
    sys.exit(0)

def load(path, default):
    try:
        with open(os.path.join(cp_dir, path)) as f:
            return json.load(f)
    except Exception:
        return default

cfg = load("config.json", {})
window   = float(cfg.get("context_window", 200000))
warn_pct = float(cfg.get("warn_pct", 70))
cooldown = float(cfg.get("cooldown_minutes", 15)) * 60
check_s  = float(cfg.get("check_seconds", 60))

now = time.time()
state_path = os.path.join(cp_dir, f"sample-{session_id}.json")
try:
    with open(state_path) as f:
        st = json.load(f)
except Exception:
    st = {}

# throttle: skip the transcript parse entirely between checks
if now - st.get("checked_at", 0) < check_s:
    sys.exit(0)

# read the transcript tail and find the latest assistant usage block
usage = None
try:
    size = os.path.getsize(transcript)
    with open(transcript, "rb") as f:
        f.seek(max(0, size - 262144))
        tail = f.read().decode("utf-8", errors="replace")
    for line in reversed(tail.splitlines()):
        try:
            e = json.loads(line)
        except Exception:
            continue
        u = (e.get("message") or {}).get("usage")
        if u and "input_tokens" in u:
            usage = u
            break
except Exception:
    sys.exit(0)
if not usage:
    sys.exit(0)

ctx = (usage.get("input_tokens", 0)
       + usage.get("cache_read_input_tokens", 0)
       + usage.get("cache_creation_input_tokens", 0))
pct = 100.0 * ctx / window

st["checked_at"] = now
st["last_pct"] = pct

def flush():
    tmp = state_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(st, f)
    os.replace(tmp, state_path)

if pct < warn_pct or now - st.get("last_injected", 0) < cooldown:
    flush()
    sys.exit(0)

st["last_injected"] = now
flush()

reason = (
    f"[context-pilot] Context alert: this session's context is at ~{pct:.0f}% "
    f"of the window ({ctx:,} of {window:,.0f} tokens; threshold {warn_pct:.0f}%). "
    f"Evaluate the boundary now using the context-pilot skill's decision rule: "
    f"if the task is nearly done (t small), just finish — any transfer is pure "
    f"overhead. If the next step depends on reasoning that lives only in this "
    f"conversation, do not clear — keep working to a true boundary or accept "
    f"auto-compact. If this IS a true boundary (work verified, thoughts "
    f"externalizable as a page of pointers), run the six-component audit, write "
    f".claude/context-handoff.md, verify self-sufficiency, and invite the user "
    f"to /clear. Consult the context-pilot skill for the full protocol. This "
    f"alert repeats at most every {cooldown/60:.0f} minutes."
)
print(json.dumps({"decision": "block", "reason": reason}))
PY

exit 0
