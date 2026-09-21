---
name: android-security-gate
description: Run the four-layer Android security review on the current changes - guarded files, a diff scan for secrets and personal data and permission or dependency changes, a hardening audit, and a security review - and block the push on high-severity findings. Use when the user asks to check security, review a diff for vulnerabilities, or before pushing, or as stage 08 of the Android workflow.
---

# Security gate — stage 08 (gate 2)

Read `shared/config.md` and `shared/ticket-file.md`, then `reference.md` here.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

1. **Collect the changes**: the diff against the merge base with `base_branch`, plus staged and
   untracked files. Nothing → say so and stop.
2. **Compute the diff fingerprint** exactly as `shared/ticket-file.md` defines it.
3. **Run all four layers** from `reference.md`. Report `security.known_tracked_secrets` once as
   pre-existing, never as findings against this diff.
4. **Present findings** grouped by severity, each with `file:line` and the fix.
5. **Gate 2.**
   - No high-severity findings → record `result: pass` with the fingerprint.
   - High-severity findings → **the push is blocked.** The developer fixes them, or waives one by
     giving a written reason, which you record verbatim. Never invent a reason and never waive on
     your own initiative.
6. **Write the result** to the ticket file and end with one line: whether the push is clear.

Run every layer even when the first one finds something. A developer deserves the whole list at
once, not one finding per round trip.
