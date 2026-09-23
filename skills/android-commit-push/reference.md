# Commit and push — rules

Stage 09, gate 3. The last point where a person sees the change before it leaves the machine.

## Pre-flight, in order

1. **HEAD is not on a protected branch.** On one → stop, name `/android-branch`, change nothing.
   The hook would deny the commit anyway; this refusal explains it instead of hitting a wall.
2. **The security gate has passed for these exact changes.** Recompute the diff fingerprint and
   compare it with `security.diff` in the ticket file. Missing, `fail`, or a different fingerprint
   → run the `android-security-gate` skill now and continue only if it clears.
3. **The code review's verdict is read, not required.** The review is advisory: take
   `review.result`, `review.must_fix` and `review.diff` from the ticket file for gate 3. Never run
   the review here and never hold the push for it — but never leave its findings unsaid either.
4. **Nothing is staged yet.** Whatever the run staged earlier, the developer approves the file list
   before anything is added.

## The commit message

```
<KEY>: <name>
```

The name is the ticket's `name` from the ticket file, verbatim. Missing → ask; do not invent a
summary from the diff.

No trailers. No `Co-Authored-By`, no "Generated with", no emoji. These commits are the developer's.

A bugfix branch collects one commit per fix, each with its own key and name. That is normal; do not
amend or squash the earlier ones.

## Gate 3 — what the developer sees

Show all three, then stop and wait:

```
message:  TA-1234: Subscription cancel reason
files:    app/src/main/java/.../CancelReasonSheet.kt   (new)
          app/src/main/java/.../SubscriptionViewModel.kt
          app/build.gradle
          FirebaseAppDistributionConfig/release_notes.txt
target:   feature/TA-1234 → origin
```

Plus every waiver, quoted, so it is read one more time before it reaches a reviewer:

```
waivers:  security  "new dependency com.foo:bar" — vendor SDK required by TA-1234, agreed with the security owner
          related   TA-2002 (UI, DEVELOPMENT) — "Design signed off in the review call; ticket not moved yet"
review:   2 must-fix findings, not fixed (advisory) — run /android-review to see them
```

A `jira-waived` intake is shown the same way, with the ticket's own key.

The review line comes from the ticket file's `review:` block:

| In the file | Shown |
|---|---|
| `result: pass`, fingerprint current | `review:   clear` |
| `result: findings`, fingerprint current | `review:   <n> must-fix findings, not fixed (advisory) — run /android-review to see them` |
| fingerprint not the current one | the same line plus `— recorded against older code` |
| no `review:` block | `review:   not run` |

It is a line to read, not a stop: the review never blocks the push. Saying it here is how a finding
nobody fixed reaches the person who reviews the pull request.

**One confirmation covers staging, committing and pushing.** Do not ask three times, and do not
stage anything before the answer. A "no" ends the stage cleanly: nothing staged, nothing committed,
and a line saying where the run stopped.

**No answer is a no.** A run that cannot ask — nobody present, a non-interactive session, a
chain driven by a script — shows gate 3 and stops there. It never reads "I could not ask" as
permission to push. (Found 2026-09-22: a non-interactive run reasoned its way past gate 3 and
pushed; only the scratch remote received it.)

## After the push

Record `pushed: <sha>` in the ticket file.

**Never force-push.** A rejected push (the remote moved) is reported, not forced: the developer
decides whether to rebase.

**Never run Fastlane.** Distribution is CI's, and the note for testers is stage 10.

## The draft PR

Only when `distribution.open_draft_pr` is true, and only after a successful push:

```bash
gh pr create --base <base_branch> --head <branch> --draft --fill
```

`gh` is the only way a skill can open a PR: `/pr` is a slash command a person types, not something
a skill can invoke.

Check it works before offering: `gh auth status`. Two failure modes worth naming, because both are
common on these machines:

- `gh` not installed → print the compare URL instead.
- `gh` installed but an invalid `GITHUB_TOKEN` in the environment overrides a working keyring
  login → say exactly that, since the fix is to unset the variable, not to log in again.

The fallback is always:

```
<remote-web-url>/compare/<base_branch>...<branch>?expand=1&draft=1
```

Ask before opening it. A draft PR is outward-facing: it notifies reviewers.
