# Commit and push — rules

Stage 09, gate 3. The last point where a person sees the change before it leaves the machine.

## Pre-flight, in order

1. **HEAD is not on a protected branch.** On one → stop, name `/android-branch`, change nothing.
   The hook would deny the commit anyway; this refusal explains it instead of hitting a wall.
2. **The security gate has passed for these exact changes.** Recompute the diff fingerprint and
   compare it with `security.diff` in the ticket file. Missing, `fail`, or a different fingerprint
   → run the `android-security-gate` skill now and continue only if it clears.
3. **Nothing is staged yet.** Whatever the run staged earlier, the developer approves the file list
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

Plus any security waivers, quoted, so they are read one more time before they reach a reviewer.

**One confirmation covers staging, committing and pushing.** Do not ask three times, and do not
stage anything before the answer. A "no" ends the stage cleanly: nothing staged, nothing committed,
and a line saying where the run stopped.

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
