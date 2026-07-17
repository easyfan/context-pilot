#!/usr/bin/env bash
# context-pilot delivery layer: SessionStart hook.
#
# "/clear, then continue with X" is unpronounceable for the model — the context
# that says it is destroyed by it. The instruction is split into three
# harness-level frames: (1) before the clear, the session writes a handoff file
# and passes the self-sufficiency gate (the context-pilot skill); (2) the HUMAN
# presses /clear; (3) this hook re-injects the handoff into the cold session.
#
# The hook is deliberately SOURCE-AGNOSTIC. Measured behavior (CC 2.1.20x):
# stock Claude fires SessionStart with source=clear on /clear; the happy app
# implements /clear as a new session and fires source=startup. Filtering on
# source would silently break one of the two. The discriminator is the handoff
# file's existence plus a freshness guard, not the source label:
#   * fresh handoff (mtime within CONTEXT_PILOT_FRESH_SECONDS, default 900)
#     → inject it as additionalContext with a cold-reader preamble, then
#       consume it (rename to context-handoff.last.md) so an unrelated later
#       session can never re-ingest it.
#   * missing or stale handoff → exit 0 silently; normal sessions unaffected.
#   * source=resume → exit 0 (an in-place resume still has its context).
#
# The injected preamble is load-bearing (design §13-②b): the cold session must
# restate its understanding and wait for user confirmation before acting, and
# ask rather than guess on ambiguity — this converts the "confident misreading"
# silent failure into a clarifying question.
#
# auto_proceed exception: when the handoff's first line is `auto_proceed: true`
# (written by /clear-then only after the self-sufficiency gate passed), the
# restate stays — it is the misreading barrier — but the confirmation WAIT is
# waived: the user already dictated the next step when they issued /clear-then,
# so a second confirmation is pure friction. A handoff without the flag (plain
# context-pilot, or hand-written) keeps the full wait-for-confirm path.
#
# Env overrides (tests):
#   CONTEXT_PILOT_CWD            force project dir instead of reading stdin
#   CONTEXT_PILOT_FRESH_SECONDS  freshness window (default 900)

set -uo pipefail

PAYLOAD="$(cat 2>/dev/null || true)"
FRESH="${CONTEXT_PILOT_FRESH_SECONDS:-900}"

META="$(printf '%s' "$PAYLOAD" | python3 -c '
import json,sys,os
try: d=json.load(sys.stdin)
except Exception: d={}
print((d.get("source") or "") + "\t" + (d.get("cwd") or os.getcwd()))' 2>/dev/null)"
SRC="${META%%$'\t'*}"
CWD="${CONTEXT_PILOT_CWD:-${META#*$'\t'}}"
[ -z "$CWD" ] && CWD="$PWD"

# in-place resume: the session never lost its context — nothing to deliver
[ "$SRC" = "resume" ] && exit 0

HANDOFF=""
for cand in "$CWD/.claude/context-handoff.md" "$CWD/context-handoff.md"; do
  if [ -f "$cand" ]; then HANDOFF="$cand"; break; fi
done
[ -z "$HANDOFF" ] && exit 0

HANDOFF="$HANDOFF" FRESH="$FRESH" python3 <<'PY'
import json, os, sys, time

path = os.environ["HANDOFF"]
fresh = float(os.environ["FRESH"])

try:
    age = time.time() - os.path.getmtime(path)
    text = open(path, encoding="utf-8", errors="replace").read()
except Exception:
    sys.exit(0)

# Freshness guard: in happy, a clear and a genuinely new session both arrive
# as source=startup — only recency separates "handoff written moments before
# the clear" from "stale file an old session left behind". Stale → stay silent
# (the file remains on disk for a human to inspect or delete).
if age > fresh:
    sys.exit(0)

# auto_proceed: flag on the handoff's first line, written by /clear-then only
# after the gate passed — the user has already named the next step, so the
# confirmation wait (not the restate) is waived.
first_line = text.split("\n", 1)[0].strip()
if first_line == "auto_proceed: true":
    first_turn = (
        "FIRST TURN PROTOCOL: restate in 2-3 lines your understanding of the "
        "goal and the next step, then begin that step immediately — the user "
        "already specified it via /clear-then; no confirmation wait is "
        "required. "
    )
else:
    first_turn = (
        "FIRST TURN PROTOCOL: restate in 2-3 lines your understanding of the "
        "goal and the next step, then wait for the user to confirm before "
        "doing anything else. "
    )

preamble = (
    "[context-pilot] This session follows a deliberate /clear; the handoff "
    "below is your entire inherited memory (the previous context is gone, but "
    "its transcript survives on disk — see the handoff's Session map). "
    + first_turn +
    "If any pointer or decision below is ambiguous, ask the "
    "user — do not fill gaps from plausibility. The handoff file has been "
    "consumed (renamed to context-handoff.last.md); do not look for it.\n\n"
)

# Consume-once: rename rather than delete — if the injection is lost (crash
# between hook and model), the content is still recoverable by a human, yet a
# later unrelated session can never re-ingest it under the canonical name.
try:
    os.replace(path, os.path.join(os.path.dirname(path), "context-handoff.last.md"))
except Exception:
    pass

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": preamble + text,
    }
}))
PY

exit 0
