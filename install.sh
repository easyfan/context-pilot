#!/usr/bin/env bash
# install.sh — context-pilot manual installer (for users not using /plugin install)
# Usage: ./install.sh [--dry-run] [--uninstall] [--target=<path>]
#   --dry-run          Preview changes without writing
#   --uninstall        Remove installed files and deregister the hooks
#   --target=<path>    Custom Claude config directory (default: ~/.claude)
#   CLAUDE_DIR=<path>  Alternative to --target
#
# Installs:
#   <target>/skills/context-pilot/SKILL.md      the safe-to-forget protocol skill
#   <target>/commands/clear-then.md             the /clear-then command
#   <target>/context-pilot/hooks/*.sh           delivery + sampling hooks
#   <target>/settings.json                      SessionStart + PostToolUse hook entries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DRY_RUN=0
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --target=*) CLAUDE_DIR="${arg#--target=}" ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

HOOK_DIR="$CLAUDE_DIR/context-pilot/hooks"
SKILL_DST="$CLAUDE_DIR/skills/context-pilot"
CMD_DST="$CLAUDE_DIR/commands/clear-then.md"
SETTINGS="$CLAUDE_DIR/settings.json"

run() { if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

register_hooks() {
  if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] register hooks in $SETTINGS"; return; fi
  SETTINGS="$SETTINGS" HOOK_DIR="$HOOK_DIR" MODE="add" python3 <<'PY'
import json, os

settings_path = os.environ["SETTINGS"]
hook_dir = os.environ["HOOK_DIR"]
mode = os.environ["MODE"]

try:
    with open(settings_path) as f:
        s = json.load(f)
except Exception:
    s = {}

hooks = s.setdefault("hooks", {})

def entry(script, matcher=None):
    e = {"hooks": [{"type": "command", "command": os.path.join(hook_dir, script)}]}
    if matcher is not None:
        e["matcher"] = matcher
    return e

def is_ours(e):
    return any("context-pilot/hooks/context_" in h.get("command", "")
               for h in e.get("hooks", []))

for event, script, matcher in (
        ("SessionStart", "context_deliver.sh", None),
        ("PostToolUse", "context_sample.sh", "*")):
    lst = [e for e in hooks.get(event, []) if not is_ours(e)]
    if mode == "add":
        lst.append(entry(script, matcher))
    if lst:
        hooks[event] = lst
    else:
        hooks.pop(event, None)

if not hooks:
    s.pop("hooks", None)

tmp = settings_path + ".tmp"
with open(tmp, "w") as f:
    json.dump(s, f, indent=2)
os.replace(tmp, settings_path)
print(f"settings.json: context-pilot hooks {'registered' if mode=='add' else 'removed'}")
PY
}

deregister_hooks() {
  if [ "$DRY_RUN" = 1 ]; then echo "[dry-run] deregister hooks in $SETTINGS"; return; fi
  [ -f "$SETTINGS" ] || return 0
  SETTINGS="$SETTINGS" HOOK_DIR="$HOOK_DIR" MODE="remove" python3 <<'PY'
import json, os

settings_path = os.environ["SETTINGS"]

try:
    with open(settings_path) as f:
        s = json.load(f)
except Exception:
    raise SystemExit(0)

hooks = s.get("hooks", {})

def is_ours(e):
    return any("context-pilot/hooks/context_" in h.get("command", "")
               for h in e.get("hooks", []))

for event in list(hooks):
    kept = [e for e in hooks[event] if not is_ours(e)]
    if kept:
        hooks[event] = kept
    else:
        hooks.pop(event)

if not hooks:
    s.pop("hooks", None)

tmp = settings_path + ".tmp"
with open(tmp, "w") as f:
    json.dump(s, f, indent=2)
os.replace(tmp, settings_path)
print("settings.json: context-pilot hooks removed")
PY
}

if [ "$UNINSTALL" = 1 ]; then
  echo "Uninstalling context-pilot from $CLAUDE_DIR ..."
  deregister_hooks
  run rm -rf "$SKILL_DST" "$CLAUDE_DIR/context-pilot"
  run rm -f "$CMD_DST"
  echo "Done. Handoff/state files in projects (if any) were left untouched."
  exit 0
fi

echo "Installing context-pilot into $CLAUDE_DIR ..."
run mkdir -p "$SKILL_DST" "$HOOK_DIR" "$CLAUDE_DIR/commands"
run cp "$SCRIPT_DIR/skills/context-pilot/SKILL.md" "$SKILL_DST/SKILL.md"
run cp "$SCRIPT_DIR/commands/clear-then.md" "$CMD_DST"
run cp "$SCRIPT_DIR/hooks/context_deliver.sh" "$HOOK_DIR/context_deliver.sh"
run cp "$SCRIPT_DIR/hooks/context_sample.sh" "$HOOK_DIR/context_sample.sh"
run chmod +x "$HOOK_DIR/context_deliver.sh" "$HOOK_DIR/context_sample.sh"
register_hooks

echo "Done. Components:"
echo "  skill   : $SKILL_DST/SKILL.md"
echo "  command : $CMD_DST  (/clear-then <next step>)"
echo "  hooks   : $HOOK_DIR (SessionStart delivery + PostToolUse sampling)"
echo "Optional config: ~/.claude/context-pilot/config.json"
echo '  {"context_window": 200000, "warn_pct": 70, "cooldown_minutes": 15}'
