# Unit tests — rules

Stage 07. JVM unit tests only: `src/test`, never `src/androidTest` (those need a device and belong
to QA, not to this workflow).

## Resolving the scope

**With an argument** (`subscriptions`, `SubscriptionViewModel`, `domain.model.iap`): match it
case-insensitively against test class names and the package path under `src/test`.

```bash
find . -path '*/src/test/*' -name '*Test.kt' | grep -i "<scope>"
```

**List what matched before running anything**, so the developer sees the scope you chose:

```
6 test classes match "subscriptions":
  SubscriptionTierActionTest, CancelTierSubscriptionTest, …
```

**No match** → say so, show the three nearest names, and stop. Never widen a failed match into a
full-suite run: a developer who asked for one feature did not ask for a twelve-minute build.

**No argument** → the tests related to the current changes. Take the changed files (the command in
`android-lint/reference.md`), map each class `Foo` to `FooTest`, and include tests whose package
matches a changed file's package. None found → say so and suggest `--all`.

**`--all`** → the whole suite, no filter.

## Running

```bash
JAVA_HOME=<resolved jdk> ./gradlew <build.test_task> --tests '*<Scope>*'
```

Several patterns: repeat `--tests`. Quote the pattern — the shell eats a bare `*`.

Report the real result, quoting the output: how many ran, how many failed, how long it took.
**Never report a pass you did not see.** Gradle not runnable (no wrapper, no JDK, a broken build)
is a legitimate outcome: say which, and stop.

## Failures

For each failing test: its name, the assertion message, and `file:line`. Then say whether the
production code or the test is wrong, and why.

**Never make a test pass by weakening it.** Deleting an assertion, loosening a matcher, adding
`@Ignore`, or catching the exception the test exists to detect are all ways of reporting a pass
that is not one. If the test is genuinely wrong, say so and change it deliberately, explaining
what behaviour it should assert instead.

## Writing tests

Only in a feature chain, or when asked. Follow the style already in `src/test` — read two existing
tests before writing one. The house style across these repositories:

- Fake collaborators, not mocking frameworks: a fake use case returning canned values.
- `UnconfinedTestDispatcher` with `runTest`.
- One behaviour per test, named for the behaviour: `emits error state when the api fails`.
- Assert on state the UI reads, not on internal calls.
- No Robolectric, no Android framework classes: these are JVM tests.

A bugfix chain runs the existing tests. A regression test for a trivially unit-testable bug is
welcome, never required — a fix held up by a hard-to-write test is a fix that does not ship.
