# context-pilot

**Safe-to-forget protocol for the Claude Code context window.**

[中文](README-zh.md) | [Deutsch](README-de.md) | [Français](README-fr.md) | [Русский](README-ru.md)

`/clear, then continue with X` is an instruction no model can execute: the
context that says it is destroyed by it. context-pilot compiles that
unpronounceable instruction into three harness-level frames — write a
self-sufficient handoff before the clear, let the human press `/clear`, and
auto-deliver the handoff into the cold session afterwards. The result: a
long-running session can cross a context wipe *losslessly*, instead of
dragging a fat context (a per-turn token tax) or falling back to lossy
auto-compact.

Sister plugin of [quota-pilot](https://github.com/easyfan/quota-pilot):
quota-pilot parks a session across a rate-limit window (hibernation);
context-pilot carries a session across a context wipe (amnesia with a
letter to self). They share the checkpoint philosophy — with one key
difference: quota-pilot's checkpoint is insurance, context-pilot's handoff
is the *entire memory* of the next session, which is why its gate has veto
power.

## Components

| Component | What it does |
|---|---|
| **Skill** (`context-pilot`) | The write-side protocol: a decision rule (keep working / clear / compact), a six-component audit that surfaces everything living only in conversation, cold-readability writing rules, and a self-sufficiency gate that vetoes unsafe clears. |
| **Command** (`/clear-then <next step>`) | Runs the protocol with the next step given explicitly, then hands the `/clear` keystroke to you. |
| **SessionStart hook** (`context_deliver.sh`) | Source-agnostic delivery: after you press `/clear` (stock Claude *or* the happy app), a fresh `context-handoff.md` is injected into the new session with a cold-reader preamble, then consumed (renamed) so it can never be re-ingested. |
| **PostToolUse hook** (`context_sample.sh`) | Sampling: watches context utilization from the transcript; past 70% (configurable) it injects a boundary-evaluation alert, at most once per cooldown. |

## The decision rule (what the skill enforces)

Three inputs: **t** (remaining work), **H** (handoff size needed to be
self-sufficient), **N** (distance to the ceiling — urgency only).

- **t small** → just finish; any transfer is overhead.
- **Self-sufficiency unreachable** (next step depends on reasoning still in
  flight) → do **not** clear; work to a true boundary or accept auto-compact.
- **Gate passes, H small** → write the handoff, invite `/clear`.
- **Grey zone** (H approaches compact-summary size) → compact. Compact fails
  *soft* (the model can feel a gap and re-read); a bad clear fails *silent*
  (the new session doesn't know what it doesn't know). Marginal cases go to
  the soft failure.

The handoff records, per a six-component audit: goal, concrete next step,
**decisions incl. explicitly rejected alternatives**, pitfalls, honest
unverified state, verbal user constraints — plus a session map pointing at
the old transcript (which survives the clear on disk) and the audit's own
record. Pointers, never copied content.

## Why the model can't just do this itself

Verified against the CC binary (2.1.20x): no hook output field, command
queue, or SDK control request can trigger `/clear` — clearing is strictly
human-initiated in the interactive UI. And a background subagent can't
carry the state either: its return value lands in the parent context that
is about to be destroyed. Hence this architecture: **disk file as the
custodian, SessionStart hook as the messenger, human as the trigger.**

## Install

As a plugin:

```
/plugin marketplace add easyfan/context-pilot
/plugin install context-pilot@context-pilot
```

Manual (installs skill + command + hooks into `~/.claude/`):

```bash
git clone https://github.com/easyfan/context-pilot.git
cd context-pilot && ./install.sh          # --dry-run to preview, --uninstall to remove
```

Manual hook registration (if `install.sh` aborts because python3 is missing): merge the following into `~/.claude/settings.json`:

```json
"hooks": {
  "SessionStart": [
    { "hooks": [ { "type": "command", "command": "$HOME/.claude/context-pilot/hooks/context_deliver.sh" } ] }
  ],
  "PostToolUse": [
    { "matcher": "*", "hooks": [ { "type": "command", "command": "$HOME/.claude/context-pilot/hooks/context_sample.sh" } ] }
  ]
}
```

## Configuration

Optional `~/.claude/context-pilot/config.json`:

```json
{
  "context_window": 200000,
  "warn_pct": 70,
  "cooldown_minutes": 15,
  "check_seconds": 60
}
```

> **Note for 1M-window models:** `context_window` defaults to `200000`. If your model has a 1M-token context window (e.g. `[1m]` model IDs), set it to `1000000` — with the default, alerts fire far too early and can report usage above 100%.

Delivery freshness window (how recent a handoff must be to be injected):
`CONTEXT_PILOT_FRESH_SECONDS`, default 900.

## Typical flow

1. Work long enough that the sampler injects a `[context-pilot]` alert (or
   just say "can I clear safely?" / run `/clear-then implement phase 2`).
2. The skill runs the decision rule. If this is a true boundary it writes
   `.claude/context-handoff.md`, passes the self-sufficiency gate, and tells
   you it is safe.
3. You press `/clear`.
4. The new session starts with the handoff injected, restates its
   understanding in 2–3 lines, and waits for your go-ahead — or, if the
   handoff was written by `/clear-then` (it carries `auto_proceed: true`),
   begins the named next step right after restating, no wait — then
   continues with a near-empty, clean context.

## Files

```
skills/context-pilot/SKILL.md   the protocol
commands/clear-then.md          /clear-then
hooks/context_deliver.sh        SessionStart delivery (consume-once)
hooks/context_sample.sh         PostToolUse sampling
hooks/hooks.json                plugin hook registration
install.sh                      manual installer
evals/evals.json                behavioral eval set (benchmarked +26pp vs no-skill)
```

## License

MIT
