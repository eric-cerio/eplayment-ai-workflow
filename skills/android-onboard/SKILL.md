---
name: android-onboard
description: Set up an Android repository for the Copilot Android workflow by detecting its build, versioning, release-notes and distribution conventions and writing .ai/project/android-workflow.yml. Use when a repo has no workflow config, when another workflow skill says to run onboarding, or when adopting the workflow in a new Android project.
---

# Onboard a repository

Read `shared/config.md` for the file you are writing, then `reference.md` here for how to
detect each value.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

1. **Check this is an Android repository.** No Gradle file applying `com.android.application` →
   stop and say so. This workflow is for Android apps.
2. **Check AICS.** No `.ai/` directory → tell the developer `epm aics install` must run first,
   offer to run it, and **wait for a yes**. Never run it unasked.
3. **Already configured?** If `.ai/project/android-workflow.yml` exists, show it, say what you
   would change, and ask before overwriting.
4. **Detect** every key using `reference.md`. Keep two lists as you go: detected, and guessed.
5. **Draft the architecture docs** if `.ai/project/architecture.md` or `conventions.md` are
   missing, as `reference.md` describes.
6. **Ask** about what you could not settle, one question at a time. `app_tag` is always asked, even
   when you can guess it.
7. **Write** `.ai/project/android-workflow.yml`. Order the keys as `shared/config.md` shows, keep
   its comments, and set `workflow_version` from this plugin's `plugin.json`.
8. **Show** the result: the file, then `git status --short`. **Do not commit.** The config belongs
   in a normal PR with a human reviewer.
9. **Report**, as four short lists:
   - what you **detected**, one line each with the evidence;
   - what you **guessed**, which the developer should check;
   - **legacy files** that can now be deleted, and **secrets already tracked in git**, which need
     rotating by whoever owns the repository;
   - **connections**: whether the Atlassian and R&D Handbook servers are connected, per
     `reference.md`.

Detect, then ask. Never write a value you did not detect and did not confirm.
