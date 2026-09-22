# Release notes and version — rules

Recovered from `.github/pixel-workflows/versioning.md`, which knew only one of the two versioning
rules in use across the Android repositories. Both are documented here; the repository's
`versioning.rule` decides which applies.

## Release notes

Line format, one per ticket:

```
<jira_base><KEY>
```

`mode: append` — append the line to `release_notes.file` if that exact URL is not already present.
Never reorder, deduplicate or reset the rest of the file: it accumulates the build's tickets across
branches, and stage 10 reads it in file order.

`mode: replace` — the file holds this branch's ticket(s) only. Replace its contents with this
ticket's URL. On a batch branch carrying several tickets, keep the ones already there for that
branch and add this one.

Either way the file ends with a single newline, and no other file is touched.

## Version

Read `versionName` from `build.gradle_file`. **`versionCode` is never written by this workflow** —
CI and release own it, and the guard-rails hook denies the edit anyway.

### `rule: patch-bump`

Bump the last segment only:

```
versionName "3.4.27"   →   versionName "3.4.28"
```

Nothing else about the string changes. If it already carries a suffix, that is a different
convention in the same repo — stop and ask rather than guessing.

**Once per branch.** Compare with the base before bumping:

```bash
git show "$(git merge-base HEAD <base_branch>):<build.gradle_file>" | grep -m1 versionName
```

The working tree's `versionName` already differs from the base's → this branch has been bumped;
say "already bumped on this branch (3.4.27 → 3.4.28)" and change nothing. A chain that stops and
is run again must not bump twice.

### `rule: branch-suffix`

Append the branch topic to the base version, once:

```
versionName "2.13.9"   →   versionName "2.13.9-realtime-bank-transfer-status"
```

The topic is the branch name with its prefix removed and `/` turned into `-`:

| Branch | Topic |
|---|---|
| `feature/realtime-bank-transfer-status` | `realtime-bank-transfer-status` |
| `feature/TA-1234` | `TA-1234` |
| `subscriptions/TA-1234` | `TA-1234` (stacked branch: the segment after the epic) |
| `bugfix/antimony` | `antimony` |

**Never stack suffixes.** If the current `versionName` already carries one (`2.13.9-something`),
strip it back to the base version before appending, so `2.13.9-a-b` can never appear. The base
version is the leading `MAJOR.MINOR.PATCH`.

Do not bump any number under this rule: the base version comes from the base branch, and the
suffix is what marks the build as this branch's.

## Registering the branch for distribution

Only when `distribution.register_branch_in` names a workflow file. Add the current branch to that
file's `push.branches` list if it is absent:

```yaml
on:
  push:
    branches: [ develop, feature/TA-1234 ]
```

Match the existing style — inline list or block list, quoted or not — and change nothing else in
the file. Already present → say so and move on.

## Reporting

Print a diff summary of every file changed: the version line before and after, the release-notes
line added or replaced, and the workflow branch list if touched. **Stage nothing**; stage 09 does
that, after the developer has seen it.
