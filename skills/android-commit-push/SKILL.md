---
name: android-commit-push
description: Commit and push the current Android ticket's work after showing the exact commit message, file list and push target, then offer the draft pull request. Use when the user asks to commit and push their ticket, or as stage 09 of the Android workflow. Requires a passing code review and security gate for the current changes.
---

# Commit and push — stage 09 (gate 3)

Read `shared/config.md` and `shared/ticket-file.md`, then `reference.md` here.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

1. **Refuse on a protected branch.** Point at `/android-branch`.
2. **Require a current review, then a current security pass.** Recompute the diff fingerprint.
   No matching `review: pass` → run the `android-review` skill now and continue only if it clears.
   Then no matching `security` `pass` or `waived` → run the `android-security-gate` skill now and
   continue only if it clears.
3. **Build the message** `<KEY>: <name>` from the ticket file. Missing name → ask.
4. **Gate 3.** Show the message, the file list, the target `<branch> → <remote>`, and every waiver —
   security and related-ticket — quoted.
   **Stop and wait.** Nothing is staged before the answer, and one yes covers staging, committing
   and pushing. **Only an explicit yes counts**: no answer — nobody there to ask, a
   non-interactive session — is a no. Stop with nothing staged, committed or pushed.
5. **Stage exactly those files**, commit with no trailers, push the branch. **Never force-push.**
6. **Record** `pushed: <sha>` in the ticket file.
7. **Offer the draft PR** when `distribution.open_draft_pr` is true, per `reference.md`. Ask first:
   it notifies reviewers.

Never run Fastlane. Never amend or squash earlier commits on a bugfix branch.
