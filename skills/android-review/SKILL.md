---
name: android-review
description: Review the Android changes on this branch for correctness, the repository's architecture and conventions, the backend contract, the Android squad standards and general practice, and block the push on must-fix findings until the code changes. Use when the user asks for a code review, a quality or standards check of their changes, or before pushing, or as stage 07b of the Android workflow.
---

# Code review — stage 07b (hard block)

Read `shared/config.md` and `shared/ticket-file.md`, then `reference.md` here.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

1. **Resolve the ticket key**: argument → branch name → ask. "none" is an answer: review anyway,
   without the ticket's sources, and record nothing.
2. **Collect the change set** with the command in `reference.md`. Nothing → say so and stop.
3. **Load the sources** in `reference.md`'s order, and say which you could not load.
4. **Review** every changed hunk, reading the whole file for context, against `reference.md`.
   Label every finding with its source.
5. **Present all findings at once**, must-fix first, grouped by file, each with `file:line`; each
   must-fix also with its failure scenario and its fix.
6. **Must-fix present → the push is blocked, and there is no override** — no waiver, no dismissal.
   Ask whether to fix them, and edit **only on an explicit yes**. No answer — nobody there to ask,
   or asking is not possible — **is a no**: stop with `review.result: fail` and "Fix them, then
   rerun `/android-ship`". After a fix, run the `android-lint` skill and the `android-test` skill
   (no argument: the tests related to the changes), then review the touched files again, until
   nothing is must-fix. **A fix counts only when lint and tests actually ran**: Gradle could not
   run for either → `review.result: fail`, say the fix is unverified, and stop.
7. **Record** `review.result` and the diff fingerprint, computed exactly as `shared/ticket-file.md`
   defines it, after the last change.
8. **Suggestions** are applied only when the developer picks them; then step 6's lint, tests and
   re-review run again, and step 7 records the new fingerprint.

End with one line: `Review: clear for the security gate`, or `Review: blocked — <n> must-fix`.

Never fix a suggestion unasked, never downgrade a must-fix to get through, and never treat code
outside the change set as part of it.
