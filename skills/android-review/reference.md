# Code review — rules

Stage 07b, **advisory**: it reports, and the developer decides. It runs after the tests (07), so
the tests written there are reviewed too, and before the security gate (08), so a fix made here is
inside the security pass. Nothing here stops a push — the security gate (gate 2) and the push
confirmation (gate 3) are still the stops.

## The change set

```bash
base="$(git merge-base HEAD <base_branch>)"
{ git diff --name-only "$base"; git diff --cached --name-only; \
  git ls-files --others --exclude-standard; } | sort -u | grep -E '\.(kt|kts|java|xml|gradle)$'
```

Review the changed hunks (`git diff "$base" -- <file>`; the whole file when it is untracked), and
read the whole file for context. Leave out the `versionName` line stage 06 changed in
`build.gradle_file`; the rest of a Gradle file's changes are reviewed.

An issue outside the changed hunks is "outside this change": mention it at most once, never as
must-fix.

## The sources, in order

| # | Source | Force | Label |
|---|---|---|---|
| 1 | `.ai/project/architecture.md`, `.ai/project/conventions.md` | binding | `repo: architecture.md` |
| 2 | the ticket file: `## Approved plan`, `## Acceptance criteria`, `## From BE tickets` | binding | `ticket: plan`, `ticket: BE contract` |
| 3 | the Android squad standards (R&D Handbook) | per page status | `standard: <path> (<status>)` |
| 4 | general Kotlin, Android and Compose practice | suggestion | `general practice, not a company standard` |

**The squad standards**, as `.ai/department/rnd-squad-standards.md` describes when the repository
has it: identity from `git config user.email`; `lookup_person` for the squads and their
`owns_paths`; `get_page` on the `/standards/android/` index, then only the pages this change needs
(Compose, networking, testing — whatever the hunks touch); and the `/standards/engineering/` pages
outside `api/` and `git-workflow/`. Quote each page's path and `status`:

- `active` → binding, like source 1;
- `draft` → a suggestion that says it is draft;
- `not-started` → nothing to apply.

`squads: []` or no identity → do not guess a squad: the files are Android, so use
`/standards/android/` and say that is the basis. Server not connected → report "squad standards
not checked" and continue.

A standard or a practice never makes something must-fix on its own; a failure scenario does.

The label is always the **source** from this table, never the name of a check below. A must-fix
from the table below that no repository file or ticket states — `!!` on outside data, say — is
labelled `general practice, not a company standard`, and is must-fix because of its scenario.

## Must-fix

"Must-fix" is the top severity, not a block: it marks a finding a reviewer would send back. Each
carries `file:line` and a **failure scenario**: the input or state, and what goes wrong. No
scenario → it is a suggestion, whatever its topic. The bar stays high precisely because nothing
enforces it: a list padded with opinion is a list nobody reads.

| Check | A must-fix looks like |
|---|---|
| Plan and acceptance criteria | a criterion not met: "AC 2 wants an error state; a failed cancel leaves the old status on screen" |
| BE contract | a field name, type or nullability that differs from `## From BE tickets`: `@SerializedName("reason_code")` where the contract says `reasonCode` |
| Error and empty states | a network call whose failure or empty result reaches no UI state |
| `!!` on outside data | `response.body()!!`, `intent.getStringExtra("id")!!`, `arguments!!` |
| Main thread | disk, network or database work with no background dispatcher on a path from the UI |
| Leaks | a `Context`, `Activity`, `View` or `Fragment` held by a ViewModel, a singleton or a companion object |
| Scope | `GlobalScope.launch`; `runBlocking` on the main thread |
| Lifecycle | a `Flow` collected in a Fragment or Activity outside `repeatOnLifecycle` / `flowWithLifecycle` |
| Layering | a break in the layering `architecture.md` requires: a ViewModel calling an `*Api`, a Composable calling a repository |
| Wiring | a new ViewModel, use case, repository or screen with no DI binding or factory, or no route, where `architecture.md` requires one |
| Tests | a stage 07 test that asserts nothing, asserts a constant, or whose expectation was edited to match wrong output |

## Suggestions

Never block: draft standards; general practice; naming; readability; duplication (a second helper
beside one that already does the job); Kotlin idiom; Compose structure — state hoisting, stable
parameters, `remember` keys, previews — unless it produces a wrong UI, which is must-fix with its
scenario.

## Not this stage's

Formatting and lint belong to stage 05: do not repeat them. Security — secrets, personal data in
logs, permissions, pinning, cleartext — belongs to stage 08: note "for the security gate" and move
on.

## Presenting

```
MUST-FIX  app/src/main/java/.../CancelReasonViewModel.kt:15   [repo: architecture.md]
  The ViewModel calls CancelApi directly; architecture.md requires ViewModel → UseCase → Repository → Api.
  Scenario: any submit bypasses CancelRepository's Result mapping, so a 4xx reaches no error state.
  Fix: inject CancelUseCase and map its Result to the UI state.

SUGGESTION  app/src/main/java/.../CancelReasonViewModel.kt:9   [general practice, not a company standard]
  Expose a sealed UI state instead of a bare String status, so the screen can render loading and error.
```

## The fix loop

- Ask once: `Fix the must-fix findings now? (Y/N)`. Y → change exactly those. N → record
  `result: findings` and carry on; the chain continues to the security gate.
- **Only an explicit yes allows an edit.** No answer is a no: a run that cannot ask — nobody
  present, a non-interactive session — reports the findings, records them, and changes no file.
  The developer may have written this code by hand; it is not the review's to rewrite unasked.
- After a fix: the `android-lint` skill, then the `android-test` skill with no argument (the tests
  related to the changes). A failure there stops the chain, as it does anywhere else.
- **A fix is verified only by lint and tests that ran.** Gradle could not run for either — no
  wrapper, no JDK, a broken build → say the fix is unverified and leave the finding standing
  rather than recording `pass` on top of a check that did not run. No tests cover the touched
  classes → say so; that alone changes no verdict.
- Review the files the fix touched again, not the whole change set.
- A developer who thinks a finding is wrong reruns the review with the context that shows it. The
  finding stands or falls on its scenario: context showing the scenario cannot happen (the BE
  contract guarantees the field, say) makes it not must-fix.

## Recording

Write `review.result` — `pass` with zero must-fix left, else `findings` — `review.must_fix`, the
count, and `review.diff`, the fingerprint from `shared/ticket-file.md`, after the last change.
`android-commit-push` repeats that summary at gate 3, which is how an unfixed finding reaches the
person reviewing the pull request.
