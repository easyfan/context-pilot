---
description: Prepare a safe /clear with an explicit next step — runs the context-pilot handoff protocol around the given task, then hands the /clear keystroke to you
argument-hint: <what to continue with after the clear>
---

The user wants to clear the context and then continue with: **$ARGUMENTS**

"Clear, then X" cannot be executed atomically — clearing destroys the
context that issued the instruction, and no tool or hook can trigger
`/clear` programmatically. This command is the split version: externalize
X and everything the next session needs, verify self-sufficiency, then let
the human press the button.

Follow the context-pilot skill's protocol (read its SKILL.md if it is not
already in context), with two specializations:

1. **The next step is given** ($ARGUMENTS above) — use it as the handoff's
   "Next step", made concrete to the command/file level. If it is too vague
   to be executable cold (e.g. "continue the refactor"), sharpen it from
   the current conversation before writing.
2. **The user has already chosen to clear**, so skip the "is a transfer
   wanted" question — but the safety gate still applies in full. Run the
   six-component audit, write `<project>/.claude/context-handoff.md`, and
   run the self-sufficiency test. If the test fails and the missing pieces
   cannot be externalized cleanly, say so and recommend the alternative
   (work to a real boundary, or auto-compact) — do not write a handoff that
   pretends to be complete just because the user asked to clear.
3. **Mark the handoff auto-proceed** — after writing it, and only if the
   self-sufficiency test passed: prepend `auto_proceed: true` as the first
   line of the handoff file (above the `# Context Handoff` heading). The
   user has already named the next step in $ARGUMENTS, so the SessionStart
   hook will tell the incoming session to restate and then begin
   immediately, skipping the confirmation wait. If the test did not pass,
   do not write the flag.

End with one short paragraph: the verdict, where the handoff is, and — if
the gate passed — that it is now safe to press `/clear`.
