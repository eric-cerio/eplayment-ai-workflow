# Development — rules

Stage 04, and the one stage that is optional. The developer may write the code themselves and
rejoin at stage 05 with `/android-ship`; the conventions below apply either way.

## The plan is the contract

This stage implements the plan recorded in the ticket file. It does not re-plan, widen scope, or
add "while we're here" improvements. Something in the plan turns out to be wrong → stop, say what
and why, and let the developer decide. Silently doing something other than what was approved
defeats gate 1.

## Where the templates live

The repository's `.ai/project/architecture.md` owns the layer templates, the naming, and which
pattern applies to new code. Read it and follow it. This file does not restate it, because a
template copied into a plugin goes stale the moment a repository changes its mind.

Typical shape across these apps, for orientation only:

```
ViewModel → UseCase (interface) → UseCaseImp → Repository → Api
```

with routes registered in the navigation graph and bindings added to the DI module.

## A feature

1. **Reuse first.** Everything probe 1 listed in the plan is used as-is. A second use case beside
   the one that already does the job is the failure this workflow exists to prevent.
2. **Scaffold only the files the plan named**, following the repo's templates and the recorded
   pattern (`architecture` in the ticket file).
3. **Wire it end to end**: use case to repository to API, route registered, DI bound. A screen that
   compiles but is unreachable is not done.
4. **The UI**: build from the UI reference when the plan has one; otherwise from the acceptance
   criteria, saying which. Map onto the design system — no hardcoded colours, dimensions or
   strings — and **flag every visual assumption you made**, so the developer can check it against
   the design rather than discovering it in review.
5. **After any `@Composable`**, run the Compose checks the repository's `architecture.md`
   describes, and fix what they flag.

## A bugfix

1. **The smallest correct change.** Follow the pattern of the code you are touching, in place.
2. **No refactoring beyond the fix**, no renaming, no reformatting of untouched lines. A fix that
   arrives as a 400-line diff cannot be reviewed as a fix.
3. **No new scaffolding.** If the fix seems to need a new layer, that is a plan-level change: stop
   and say so.
4. Same Compose checks if a `@Composable` is touched.

## Strings, logs and secrets

- User-facing text goes in `strings.xml`, reusing an existing entry with the same text.
- No personal data in logs. No secrets in code, ever — not even a placeholder that "will be
  replaced later".
- Nothing under `security.guarded_files` is touched without the developer confirming it.

## What this stage does not do

Lint, test, version, commit, push, or write the distribution note. Those are stages 05 to 10, each
with its own skill. End by printing the files created and changed, and the next step.
