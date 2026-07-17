---
name: context-pilot
description: Safe-to-forget protocol for the context window — decide at a task boundary whether to keep working, /clear with a self-sufficient handoff, or fall back to auto-compact; then write the handoff checkpoint through a six-component audit so nothing needed is lost when the context is destroyed. Use this skill whenever a [context-pilot] alert is injected into the conversation, whenever the user asks to prepare for /clear, mentions "handoff", "checkpoint before clear", "can I clear safely", says the context is getting full or auto-compact is approaching, or when a context-handoff.md file is present in the project. For "clear, then X" requests use the /clear-then command instead. Also use this skill when the user weighs compact vs clear, or asks "what would we lose if I cleared right now".
---

# context-pilot — the safe-to-forget protocol

`/clear` destroys the context window. Anything that lives only in the
conversation — decisions argued out loud, dead ends already explored, the
true status of half-done work — is gone the instant the user presses it.
The handoff file you write here is not a note: **it is the entirety of the
next session's memory**. That asymmetry drives every rule below.

You cannot clear the context yourself; no tool, hook, or output can trigger
it. Only the human can press `/clear`. Your job is the write side: decide
whether clearing is safe and profitable, and if it is, produce a handoff
that passes the self-sufficiency test — then tell the user it is safe to
press the button.

**The invariant:** handoff written ∧ self-sufficiency test passed ⟹ only
then invite `/clear`. If the test fails, do not invite it — keep working to
a real boundary, or recommend auto-compact instead.

Paths:
- Handoff file: `<project>/.claude/context-handoff.md`
- Old transcripts (survive clear, greppable): `~/.claude/projects/<munged-cwd>/*.jsonl`

## Step 1 — Decision rule (run this before writing anything)

Three inputs decide the verdict:

- **t** — remaining work. How many more working turns does the task need?
- **H** — how much handoff it would take to make the next step
  self-sufficient. You cannot know H precisely without writing it (writing
  *is* the measurement), but the audit table below lets you estimate: lots
  of undisked decisions/pitfalls/unverified state ⟹ H is large.
- **N** — how close the context is to the ceiling (urgency only; it never
  overrides the other two).

Estimating t in discussion-type work: in analysis or design sessions,
"remaining steps" are fuzzy. Use convergence as the unit — has the current
line of inquiry reached a conclusion, and is that conclusion written down?
Each written-down convergence is a candidate boundary; an argument still in
flight means you are mid-step, and the self-sufficiency test would fail
anyway. When t is genuinely unreadable, don't force the call: say so, and
let the boundary question ride until the next convergence.

| Situation | Verdict | Why |
|---|---|---|
| t small — task is nearly done | **Do nothing.** Just finish. | Any transfer is pure overhead on a task about to end. |
| Self-sufficiency unreachable at this point (mid-debugging, next step depends on reasoning still in flight) | **Do not clear.** Keep working to a real boundary, or accept auto-compact. | A handoff that can't pass the test = the next session silently missing things it doesn't know it's missing. |
| Test passes and H is clearly small (a page of pointers) | **Write handoff, invite /clear.** | Clean transfer: new session starts near-empty instead of dragging a compacted summary every turn. |
| Grey zone — handoff would have to be nearly as large as a compact summary (~10–20% of context) | **Recommend compact.** | Compact fails *soft* (the model can feel a gap and re-read files); a bad clear fails *silent* (the new session doesn't know what it doesn't know). Under equal expected loss, silent failure is more expensive — marginal cases go to compact. |

One economic note that changes intuition: a context that still "fits" is
not free. Every turn re-reads the whole window, so a fat context is a
per-turn tax on everything that follows — under a subscription it shows up
directly as quota burn rate. "We still have headroom" is therefore never by
itself a reason to skip a transfer at a genuine boundary: with much work
remaining (t large), a clean clear pays for itself many times over no
matter how comfortable N looks. N tells you when you *must* decide; t and H
tell you *what* to decide.

State the verdict to the user in one or two sentences before acting on it.

## Step 2 — The six-component audit (write = measure)

Go through the components one by one; for each, ask the interrogation
question and write what it surfaces. Per-component auditing exists because
a single "did I write everything?" vibe-check reliably misses items — the
variance lives in the middle three rows.

| Component | Interrogation question | What to write |
|---|---|---|
| Goal | What is the task, in one paragraph? | The original request, restated plainly. |
| Next step | Is the next action concrete to the command/file level? | The first thing the new session does. Not "continue the refactor" — the actual file, command, or edit. |
| **Decisions** | What did we decide this session that is written nowhere on disk? **And what did we consider and reject?** | Each decision with its rationale, explicitly ruled ("chose X over Y because Z"). List rejected alternatives by name with why they were rejected — the classic silent failure is a cold session re-adopting a rejected plan as if it were the decision. |
| **Pitfalls** | What did we try that failed? Would a fresh session walk into it again? | Each dead end and what it taught. A pitfall not written down will be re-explored at full price. |
| **Unverified state** | For every in-flight item: what is its *true* status? | Honest half-done state: edits made but untested, commands never run. Prevents the blind-resume bug: believing an unverified change is done. |
| User constraints | What did the user say out loud that is in no file? | Verbal scope limits, preferences, "don't touch X" — verbatim where it matters. |

Two more fields are structural, not content:

- **Session map** — one line per major arc of this session, plus the path
  to this session's transcript. Clearing destroys attention, not disk: the
  old JSONL survives and can be grepped. The map turns "I don't know why we
  did this" from a dead end into a lookup — but it only works for questions
  the new session knows to ask, so it loosens the completeness bar slightly,
  it does not replace the audit.
- **Audit record** — the audit's own findings (which components had
  residue, what was externalized in response). The audit generates its own
  residue; record it or it is lost like everything else.

## Step 3 — Cold-readability rules

You are writing for a reader with no history — and you suffer the curse of
knowledge: your own context silently disambiguates your prose, so you
cannot feel your own ambiguity. Compensate mechanically:

- **Pointers, not content.** Anything already on disk gets a path (file,
  git SHA, "read scratch/findings.md"), never a copy. Copying re-imports
  the pollution you are clearing away.
- **Every pointer self-describes.** Not `see notes.md` but
  `see notes.md — the API rate-limit findings; the retry decision is at the bottom`.
- **Decisions are ruled, never implied.** "We went back and forth on X"
  is unreadable cold. Write the ruling and the reason.
- **No new shorthand.** Codenames invented this session mean nothing to
  the next one.
- **Harvest from your own context, never from the user.** Everything said
  in this conversation — traces, error output, half-finished comparisons,
  verbal decisions — is already in your window; write it down yourself.
  Asking the user to re-paste something that already appeared is the
  protocol failing at its own job.

## Step 4 — Write the handoff file

Write to `<project>/.claude/context-handoff.md`, exactly this structure.
The preamble block is load-bearing: it is the cold session's first
instruction, and it converts confident misreading into a clarifying
question. Do not omit or soften it.

```markdown
# Context Handoff — {ISO timestamp}

> **To the new session:** your context comes from this handoff; the
> previous context was cleared. Before doing anything else: restate your
> understanding of the goal and the next step in 2–3 lines, and wait for
> the user to confirm. If any pointer or decision below is ambiguous,
> ask — do not fill gaps from plausibility.

## Task goal
## Next step
## Decisions (incl. rejected alternatives)
## Pitfalls
## Unverified state
## User constraints
## Session map
- {one line per major arc}
- Transcript: ~/.claude/projects/{munged-cwd}/{session-id}.jsonl
## Audit record
```

Omit a section only if the audit genuinely surfaced nothing for it — write
`(none)` rather than deleting the header, so absence is visibly deliberate
rather than an oversight.

**auto-proceed flag (only for `/clear-then`):** if this handoff was
generated by `/clear-then` — the user themselves dictated the next step —
then, once the self-sufficiency test passes (Step 5), prepend
`auto_proceed: true` as the first line of the handoff file, above the
`# Context Handoff` heading. The SessionStart hook reads this flag and
adjusts the injected preamble: the new session still restates the goal and
next step in 2–3 lines (the misreading barrier stays), but proceeds
immediately instead of waiting for confirmation — waiting is redundant when
the user already gave the go-ahead by issuing `/clear-then`. Never write
the flag on any other path, and never before the gate has passed.

## Step 5 — The self-sufficiency test (the gate)

One boolean, asked per component, not as a single gestalt:

> **"To execute the next step, does any required information exist only in
> the conversation history — not in the handoff and not on disk?"**

Answer *no* for every component ⟺ the handoff is self-sufficient ⟺ this
is a true boundary ⟺ safe to clear. Any *yes* → either write the missing
piece and re-test, or (if it can't be externalized cleanly) the verdict
flips to "do not clear" per Step 1.

## Step 6 — Hand over

- Test passed: tell the user, in one short paragraph — the verdict, where
  the handoff is, and that it is now safe to press `/clear`. Do not press
  anything yourself; you can't.
- Test failed or grey zone: say so, name what is still entangled, and
  recommend the alternative (keep working / auto-compact).

## In the new session (consume rule)

If you are reading a fresh `context-handoff.md` (via injection or because
the user pointed you at it): follow its preamble — restate, then wait for
confirmation (or, if the handoff's first line is `auto_proceed: true`,
begin the next step right after restating), and distrust ambiguity either
way. Once work has genuinely resumed,
**rename the handoff file** to `context-handoff.last.md` (the
SessionStart hook does this automatically; if the hook ran, the file is
already renamed and you will not find the original). Do not delete it
outright — the `.last.md` copy remains recoverable if injection failed.
A consumed handoff left under its original name is indistinguishable from
a pending one and will cause false re-injection in later sessions. Reach
for the transcript in the session map only when you hit a genuine "why did
they do this" gap — routinely re-reading the old transcript re-imports the
very context the clear was meant to shed.

> **Note on hook visibility**: the SessionStart hook injects the handoff
> via `additionalContext`, a channel that is not rendered to the user as a
> visible confirmation. The expected signal that injection succeeded is the
> new session's opening message restating the goal and next step — there is
> no separate pop-up or banner. If the new session does not restate, check
> whether `context-handoff.last.md` exists (hook consumed but injection
> may have failed); if neither file exists, the hook did not fire.

## Notes

- This protocol shares its checkpoint philosophy with quota-pilot, but the
  stakes differ: quota-pilot's checkpoint is insurance (the parked session
  still remembers everything); this handoff is the *whole memory*. That is
  why quota-pilot's gate asks "does the budget fit" while this one asks
  "can we safely forget" — and why this gate, unlike that one, has veto
  power over the transfer.
- Auto-compact is not the enemy. It is the correct fallback whenever the
  test fails, the case is marginal, or no true boundary is reachable —
  lossy but soft-failing, and it needs no human action.
- The plugin ships a `/clear-then <next step>` command — it runs this same
  protocol with the next step given explicitly, so "clear, then do X" (a
  phrase no model can execute atomically, because clearing destroys the
  speaker) becomes: write the handoff around X, pass the gate, then hand
  the `/clear` keystroke to the human.
- **Context window configuration**: `context_sample.sh` defaults to
  `context_window: 200000`. If you are using a model with a 1M token
  context window, this default will cause the alert to fire at roughly
  18–20% actual usage, producing misleading warnings. Set the correct
  value in `~/.claude/context-pilot/config.json` — see README
  §Configuration for the full config schema.
