---
name: android-lint
description: Format and lint the Kotlin changes on this branch with ktlint, Android lint, and the code-sanitation checklist, on changed files only. Use when the user asks to lint, format, clean up or sanitise their Android changes, or as stage 05 of the Android workflow.
---

# Lint and sanitation — stage 05

Read `../../shared/config.md`, then `reference.md` in this folder.

1. **Resolve the changed Kotlin files** with the command in `reference.md`. None → say so and stop.
2. **ktlint**, according to `build.ktlint`.
3. **Android lint**: `./gradlew <build.lint_task>` with the resolved JDK. Report failures as
   `file:line`.
4. **The sanitation checklist**, on the changed files only, plus the repository's own
   `.ai/project/conventions.md`.
5. **Re-stage** anything that was already staged and has since been reformatted.
6. **Report** what ran, what was skipped and why, quoting the command output.

Fix only what this diff caused. Never reformat the whole tree, and never claim a clean lint you did
not see.
