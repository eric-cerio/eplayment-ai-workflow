---
name: android-review
description: Review the Android changes on this branch for correctness, the repository's architecture and conventions, the backend contract, the Android squad standards and general practice, and report must-fix findings and suggestions before the push. Use when the user asks for a code review, a quality or standards check of their changes, or before pushing, or as stage 07b of the Android workflow.
---

# Code review — stage 07b (advisory)

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
6. **Must-fix findings do not block the push.** This stage reports; the developer decides. Ask
   whether to fix them now, and edit **only on an explicit yes**. No answer — nobody there to ask,
   or asking is not possible — **is a no**: record the findings and carry on. After a fix, run the
   `android-lint` skill and the `android-test` skill (no argument: the tests related to the
   changes), then review the touched files again. **A fix counts only when lint and tests actually
   ran**: Gradle could not run for either → say the fix is unverified and leave the finding
   standing.
7. **Record** `review.result` — `pass` with no must-fix left, else `findings` — the number of
   must-fix findings, and the diff fingerprint, computed exactly as `shared/ticket-file.md`
   defines it, after the last change. `android-commit-push` repeats the summary at gate 3, so a
   finding nobody fixed reaches the pull request's reviewer.
8. **Suggestions** are applied only when the developer picks them; then step 6's lint, tests and
   re-review run again, and step 7 records the new fingerprint.

End with one line: `Review: clear for the security gate`, or `Review: <n> must-fix, <m>
suggestions — not blocking`.

Never fix anything unasked, never soften a finding because it is inconvenient, and never treat
code outside the change set as part of it. Advisory means the developer chooses — not that the
review looks away.
