# The ticket file

One file per ticket, holding what the run needs to survive between skills, sessions and days.
Because every stage reads it, a stage skill behaves the same whether a chain called it or a
developer did.

## Where it lives

```
<git-common-dir>/android-workflow/<KEY>.md
```

`<git-common-dir>` is `git rev-parse --git-common-dir`. Use that command, never a hardcoded
`.git`: in a worktree, `.git` is a file and the common dir is elsewhere, and all worktrees of a
repository share one ticket file this way.

Inside `.git/`, the file is never committed, never appears in `git status`, and never reaches a
diff or a PR. Create the directory if it does not exist.

## Resolving the ticket key

In this order, stopping at the first that works:

1. The argument the developer typed (`/android-test TA-1234`).
2. The current branch name: the first `<LETTERS>-<DIGITS>` in it (`feature/TA-1234`,
   `subscriptions/TA-1234`, `bugfix/TA-1060` all give their key).
3. Ask. Never invent one, and never carry on with a placeholder.

A branch with no key in its name (`bugfix/antimony`) is normal: a batch branch carries several
tickets, so the key comes from the argument or the question.

## Format

Markdown with a YAML header, so a developer can read and correct it by hand.

```yaml
---
key: TA-1234
name: Subscription cancel reason
type: feature                 # feature | bugfix
branch: feature/TA-1234
architecture: MVVM            # features only; the pattern stage 02 recorded
plan_approved: 2026-09-21T10:14+08:00
related:
  result: waived              # ready | waived | android-only | none | jira-waived
  checked: 2026-09-21T10:02+08:00
  tickets:
    - {key: TA-2001, role: BE, status: QA TESTING, found: link}
    - {key: TA-2002, role: UI, status: DEVELOPMENT, found: sibling}
  dropped: [TA-1999]          # listed, then dropped by the developer as unrelated
  waivers:
    - {ticket: TA-2002, reason: "Design signed off in the review call; ticket not moved yet"}
review:
  result: pass                # pass | fail
  diff: 3f2a91c               # the same fingerprint as security.diff
security:
  result: pass                # pass | fail | waived
  diff: 3f2a91c               # fingerprint of the changes that were reviewed
  waivers:
    - finding: "new dependency com.foo:bar"
      reason: "vendor SDK required by TA-1234, agreed with the security owner"
pushed: 9c1e77a
workflow_version: 0.1.0
---

## Acceptance criteria

(For a bugfix: observed vs expected.)

## From BE tickets

(API contract, environment, open findings, contract changes from comments.)

## From UI tickets

(Figma links, screens and states, copy, design changes from comments.)

## Approved plan

(What stage 02 presented and the developer approved.)
```

## The `related` block

| `result` | Meaning |
|---|---|
| `ready` | every related ticket has passed development |
| `waived` | at least one has not, and the developer gave a reason for each such ticket |
| `android-only` | a feature with no related ticket, confirmed Android-only by the developer |
| `none` | a bugfix with no related ticket |
| `jira-waived` | Jira could not be read; `waivers` holds one entry whose `ticket` is this ticket's own key |

Waiver reasons are the developer's words, verbatim. They are repeated at gate 1 and at gate 3.

## Who writes what

| Skill | Writes |
|---|---|
| `android-plan` | `key`, `name`, `type`, `architecture`, the `related:` block, the four sections, and `plan_approved` **only after the go** |
| `android-review` | the whole `review:` block |
| `android-branch` | `branch` |
| `android-security-gate` | the whole `security:` block |
| `android-commit-push` | `pushed` |
| everything else | nothing — they only read |

Write a field as soon as it is known. A run that stops at a gate still leaves behind everything
gathered up to that point, which is what lets `/ticket TA-1234` resume tomorrow.

## The diff fingerprint

`security.diff` records **which changes** were reviewed, so a pass cannot be reused after the code
moves on. It covers the tracked diff against the merge base with `base_branch`, plus staged changes
and untracked files:

```bash
{ git diff "$(git merge-base HEAD <base_branch>)"; git diff --cached; \
  git ls-files --others --exclude-standard | sort | while IFS= read -r f; do
    printf '%s ' "$f"; git hash-object -- "$f"
  done; } | git hash-object --stdin | cut -c1-7
```

An untracked file counts by its **contents**, not only its name: a new file edited after a pass
must expire that pass. `tests/run.sh` checks this command, taken from this section, against a
scratch repository.

`android-commit-push` recomputes it before asking for the push. If it differs from the recorded
value, **the security pass and every waiver in it have expired** — run the gate again. Never edit
the fingerprint to make a pass fit; that is the one thing in this file a developer should not hand-
edit either.

`review.diff` records the same fingerprint for the code review. `android-commit-push` checks the
review first, then security: a change after either expires it, and a review fix always expires the
security pass.

## When the file and the repository disagree

The repository wins, and the file is corrected:

- `branch` names a branch that no longer exists → re-resolve it, do not recreate the branch.
- `pushed` names a commit that is not an ancestor of the current branch (a rebase, an amend) →
  treat the ticket as unpushed.
- `plan_approved` is set but the plan clearly predates the current code → say so and offer to
  re-plan rather than building on a stale plan.
