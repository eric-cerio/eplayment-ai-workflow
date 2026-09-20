---
name: android-dist-note
description: Produce the copy-pasteable Android test-distribution note for a build (the [FOR QA TESTING][Android][version][APP] block followed by the Jira links). Use when the user asks for the distribution note, the tester announcement, the QA note, or after a build has been pushed for testing. Stage 10 of the Android workflow.
---

# Distribution note — stage 10

Read `../../shared/config.md` first, then `reference.md` in this folder.

1. Read `app_tag`, `release_notes.file` and `build.gradle_file` from
   `.ai/project/android-workflow.yml`. No config → stop and tell the user to run `/android-onboard`.
2. Ask whether this is **PROD** or **QA** testing.
3. Read `versionName` and `versionCode` from `build.gradle_file`.
4. Read every line of `release_notes.file`, in file order.
5. Print one fenced block: the header
   `[FOR <PROD|QA> TESTING][Android][<versionName> (<versionCode>)][<app_tag>]`, then the Jira URLs,
   one per line.

**This skill changes no files and runs no git commands.** If asked to, refuse and say so.
