# Branch rules

Recovered from `.github/pixel-workflows/branching.md`, with the base branch and the bugfix
convention moved into configuration.

Shared by both workflows: never commit or push to a protected branch; never force-push; the
working branch is where everything happens. Stages 05 onward behave the same whichever branch rule
applied here.

## Feature

After plan approval, in this order:

1. **Already on this ticket's branch** — the current branch name contains `<KEY>`
   (case-insensitively) → stay on it. Reuse beats a second branch for the same ticket.
2. **On an epic branch** — the current branch is `feature/<topic>` where `<topic>` is *not* a
   ticket key (`feature/subscriptions`, not `feature/TA-1234`) → **stack on it**, dropping the
   `feature/` prefix:

   ```bash
   git checkout -b <topic>/<KEY>        # on feature/subscriptions → subscriptions/TA-1234
   ```

   Do **not** check out the base branch first: the work belongs on top of the epic.
3. **Otherwise** — cut from the base branch:

   ```bash
   git checkout <base_branch> && git checkout -b feature/<KEY>
   ```

## Bugfix

Per `bugfix_branch_rule`:

| Value | Behaviour |
|---|---|
| `ask` (default) | Already on a `bugfix/*` branch → stay. Otherwise ask, offering the newest `bugfix/*` on the remote and `bugfix/<KEY>` |
| `batch` | Never ask: use the newest `bugfix/*` branch, or create the batch branch the developer names |
| `per-ticket` | Always `bugfix/<KEY>` |

The newest batch branch on the remote:

```bash
git for-each-ref --sort=-committerdate --count=1 \
  --format='%(refname:short)' refs/remotes/origin/bugfix
```

Both conventions are live across these repositories — `bugfix/TA-1060` alongside `bugfix/antimony`
— which is why `ask` is the default rather than a guess.

Fixes **batch** as separate commits on a batch branch: a second fix on the same branch is normal
and nothing is amended or squashed.

## A dirty working tree

Show what is uncommitted and let the developer decide before switching branches. **Never stash
silently**: a stash is invisible later, and work disappears from under someone who did not ask for
it.

Uncommitted changes that belong to this ticket are usually a reason to stay where you are, not to
branch.

## Refusals

- HEAD on a protected branch and a commit is wanted → the branch is created first; that is this
  stage's job.
- HEAD detached → stop and say so. Creating a branch from a detached HEAD hides where the work
  came from.
- The intended branch exists on the remote but not locally → check it out and track it rather than
  creating a divergent branch of the same name.

## Record

Write the resulting branch to the ticket file as `branch`, and print it.
