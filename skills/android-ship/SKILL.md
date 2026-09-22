---
name: android-ship
description: Run the finishing half of the Android workflow on the current branch - lint, release notes and version, tests, a code review, the security gate, commit and push, then the distribution note. Use when the user has written code by hand and wants it shipped, or as stages 05-10 of the Android workflow.
---

# Ship — stages 05→10

Read `shared/ticket-file.md` and resolve the ticket key: argument → branch name → ask.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

Invoke these skills in order, each in full:

| # | Skill | Stops for the developer |
|---|---|---|
| 05 | `android-lint` | — |
| 06 | `android-release-notes` | — |
| 07 | `android-test` | — |
| 07b | `android-review` | **hard block** — must-fix findings stop the chain until the code changes |
| 08 | `android-security-gate` | **gate 2** — high severity blocks the push |
| 09 | `android-commit-push` | **gate 3** — nothing staged before the yes |
| 10 | `android-dist-note` | asks prod or QA |

**Stop at the first stage that fails**, and say which one and why. A failing test, a must-fix
review finding or a blocked security gate ends the chain; it does not get skipped so the push can
proceed. Rerunning `/android-ship` after the fix is safe: stage 06 does not bump twice.

Never do a stage's work yourself: each skill owns its rules, its config keys and its reporting.
Running them in order is this skill's only job.

Refuse on a protected branch — stages 06 and 09 both need a working branch.
