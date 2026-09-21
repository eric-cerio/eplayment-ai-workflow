---
name: android-plan
description: Plan an Android feature or bugfix before any code is written - collect the ticket details, find what to reuse, detect the architecture pattern and git state, then present the plan for approval. Use when the user wants to plan a ticket or a fix, investigate what a change would touch, or as stages 01-02 of the Android workflow.
---

# Plan — stages 01+02 (gate 1)

Read `shared/config.md` and `shared/ticket-file.md`, then `reference.md` here.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

Usage: `/android-plan <KEY> [feature|fix]`. No type given → ask which it is.

1. **Intake.** Collect the three required fields, one question at a time, for whatever the
   invocation did not already supply. A required field still missing → **stop**.
   **Write them to the ticket file as soon as you have all three**, before anything else: a run
   that stops later must not lose what the developer already typed. Then ask **once** for a UI
   reference (feature) or repro steps (fix); "skip" is a complete answer, and the run continues
   either way.
2. **Probes.** Run the three in `reference.md`: code to reuse, the pattern in the touched area
   (features only), and git and ticket state. Report, do not act.
3. **Present the plan**, saying plainly what already exists and should be reused rather than
   rewritten.
4. **Gate 1.** Ask for approval of the plan, and for a feature, of the pattern choice.
   **Wait for an explicit go.** Record the ticket fields and the plan immediately; record
   `plan_approved` **only after the go**.
5. **Say what comes next**: `/android-branch`, or `/ticket <KEY>` to run the rest of the workflow.

Write no code here, not even a stub. That is `/android-develop`, and only after approval.
