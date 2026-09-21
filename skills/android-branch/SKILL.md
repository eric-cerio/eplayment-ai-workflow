---
name: android-branch
description: Create or pick the right git branch for an Android ticket - reusing the current branch, stacking on an epic branch, or cutting a new feature or bugfix branch from the base branch. Use when the user asks which branch to work on or to start a branch for a ticket, or as stage 03 of the Android workflow.
---

# Branch — stage 03

Read `shared/config.md` and `shared/ticket-file.md`, then `reference.md` here.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

1. **Resolve the key and type** from the ticket file, the argument, or by asking.
2. **Feature**: stay on a branch that already names this key; stack `<topic>/<KEY>` when on an epic
   branch; otherwise cut `feature/<KEY>` from `base_branch`.
3. **Bugfix**: follow `bugfix_branch_rule`.
4. **A dirty tree**: show it and let the developer decide. **Never stash silently.**
5. **Record** `branch` in the ticket file and print it.

Refuse on a detached HEAD. Never commit here — this stage only decides where the work goes.
