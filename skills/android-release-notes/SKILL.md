---
name: android-release-notes
description: Update the Android release notes and versionName for the current ticket, and register the branch for distribution if the repo needs it. Use when the user asks to bump the version, add the ticket to release notes, or prepare a branch for distribution, or as stage 06 of the Android workflow.
---

# Release notes and version — stage 06

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

> Paths beginning `../../` are **inside this plugin**, relative to this file — not to the
> repository you are working in. Resolve them from this skill's own directory.

1. **Resolve the ticket key**: argument → branch name → ask.
2. **Release notes**: apply `release_notes.mode` to `release_notes.file`, using
   `<jira_base><KEY>`.
3. **Version**: apply `versioning.rule` to `versionName` in `build.gradle_file`.
   **Never touch `versionCode`.**
4. **Register the branch** in `distribution.register_branch_in`, if that key names a workflow.
5. **Report** every file you changed, before and after. **Stage nothing.**

Refuse to run on a protected branch: these edits belong on the working branch. If `HEAD` is on one,
say so and point at `/android-branch`.
