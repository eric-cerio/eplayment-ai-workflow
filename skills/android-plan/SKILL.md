---
name: android-plan
description: Plan an Android feature or bugfix before any code is written - read the ticket and its related BE and UI tickets from Jira, stop if they have not passed development, find what to reuse, detect the architecture pattern and git state, then present the plan for approval. Use when the user wants to plan a ticket or a fix, check whether a ticket is ready to start, investigate what a change would touch, or as stages 01-02 of the Android workflow.
---

# Plan — stages 01+02 (gate 1)

Read `shared/config.md` and `shared/ticket-file.md`, then `reference.md` here.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

Usage: `/android-plan <KEY> [feature|fix]`. No type given → ask which it is.

**Already approved?** `plan_approved` set in the ticket file → say so, name the next step, and
stop. Re-plan only if the developer asks, and then read Jira again.

1. **Jira intake**, as `reference.md` describes: resolve the key, reach Jira, read the ticket and
   its comments, find the related `[BE]` and `[UI]` tickets, and gate on their status.
   **Jira is read-only: never change anything in it.**
   - A related ticket not passed, or dead → **stop**, unless the developer gives a reason in words
     for every such ticket.
   - Jira unreadable → **stop**, unless the developer gives a reason in words; then run the manual
     intake in `reference.md`.
2. **Record** the fields, the `related:` block and the `## From BE tickets` / `## From UI tickets`
   sections in the ticket file as soon as you have them, before anything else. Then ask **once**
   for a UI reference (feature) or repro steps (fix) — unless a `[UI]` ticket already gave a Figma
   link. "skip" is a complete answer.
3. **Probes.** Run the three in `reference.md`: code to reuse (including the BE contract against the
   existing API models), the pattern in the touched area (features only), and git and ticket
   state. Report, do not act.
4. **Present the plan**, saying plainly what already exists and should be reused rather than
   rewritten. Show the related-ticket table, every waiver verbatim, and the open findings of any
   ticket in a findings status.
5. **Gate 1.** Ask for approval of the plan, and for a feature, of the pattern choice.
   **Wait for an explicit go.** Record `plan_approved` **only after the go**. No answer — nobody
   there to ask, a non-interactive session — is not a go.
6. **Say what comes next**: `/android-branch`, or `/ticket <KEY>` to run the rest of the workflow.

Write no code here, not even a stub. That is `/android-develop`, and only after approval.
