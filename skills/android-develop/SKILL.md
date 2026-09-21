---
name: android-develop
description: Implement an approved Android plan - scaffolding a feature through ViewModel, UseCase, Repository and Api with routes and DI, or making the smallest correct fix for a bug. Use when the user asks to implement a planned ticket or write the code for a fix, or as stage 04 of the Android workflow.
---

# Development — stage 04 (the developer's call)

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

> Paths beginning `../../` are **inside this plugin**, relative to this file — not to the
> repository you are working in. Resolve them from this skill's own directory.

1. **Require an approved plan.** No `plan_approved` in the ticket file → **stop** and send the
   developer to `/android-plan`. Never improvise one: gate 1 exists to be passed, not assumed.
2. **Re-read** the approved plan, and the repository's `.ai/project/architecture.md` and
   `conventions.md`.
3. **Feature**: reuse what the plan listed, scaffold only the files it named, wire the layers,
   register routes, bind DI, build the UI against the design system, and flag every visual
   assumption.
4. **Bugfix**: the smallest correct change, in the existing pattern. No refactoring beyond the fix.
5. **Compose checks** after touching any `@Composable`.
6. **Print** the files created and changed, plus any assumptions, and name the next step
   (`/android-ship`, or the rest of the chain).

Do not lint, test, version, commit or push here. The plan is the contract: if it is wrong, stop and
say so rather than quietly doing something else.
