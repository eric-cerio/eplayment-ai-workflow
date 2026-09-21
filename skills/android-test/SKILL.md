---
name: android-test
description: Run or write Android JVM unit tests for a feature, package, class, or the current changes, using the repo's Gradle test task and the right JDK. Use when the user asks to run tests, test a feature, check whether tests pass, or add unit tests, or as stage 07 of the Android workflow.
---

# Unit tests — stage 07

Read `../../shared/config.md` and `../../shared/ticket-file.md`, then `reference.md` here.

Usage: `/android-test [scope]`, where scope is a feature word, a package fragment, a class name, or
`--all`.

1. **Resolve the scope** as `reference.md` describes, and **list what matched before running**.
   No match → show the nearest names and stop.
2. **Run** `./gradlew <build.test_task> --tests '<pattern>'` with the resolved JDK.
3. **Report the real result**, quoting the command output. If Gradle could not run, say which part
   failed and stop. **Never report a pass you did not see.**
4. **On failure**, give each failing test with its assertion message and `file:line`, and say
   whether the code or the test is wrong. **Never weaken a test to make it pass.**
5. **Writing tests**: only in a feature chain or when asked, in the style already in `src/test`.
