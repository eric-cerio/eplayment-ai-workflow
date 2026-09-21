# Lint and code sanitation — rules

Recovered from `.github/pixel-workflows/lint.md` (the last complete module set), with the Gradle
task and the JDK path replaced by configuration.

Run after implementing, before tests. Goal: the diff is formatted, lint-clean and free of debris
before it reaches the test and security stages. Operate on the **changed files**, not the whole
tree.

## The changed files

```bash
base="$(git merge-base HEAD <base_branch>)"
{ git diff --name-only "$base"; git diff --cached --name-only; \
  git ls-files --others --exclude-standard; } | sort -u | grep -E '\.kts?$'
```

Nothing there → say so and stop. Never reformat a file this branch did not touch.

## 1. ktlint — per `build.ktlint`

| Value | What to run |
|---|---|
| `gradle` | `./gradlew ktlintFormat ktlintCheck` with the resolved JDK |
| `cli` | `ktlint --format <changed files>` |
| `none` | Nothing to run. Apply the rules by hand (below) and **say so in the summary**, recommending `org.jlleitschuh.gradle.ktlint` so the stage becomes deterministic instead of judged |

The rules to apply by hand when ktlint is absent: no wildcard imports, imports ordered, 4-space
indent, no trailing whitespace, a single trailing newline, trailing commas and spacing consistent
with the surrounding file.

Re-stage any file ktlint reformats that was already staged, so the commit holds the formatted
version.

## 2. Android lint

```bash
JAVA_HOME=<resolved jdk> ./gradlew <build.lint_task>
```

Fix **errors** introduced by the diff. Surface **warnings** in the summary. Do not chase
pre-existing issues unrelated to this ticket — a lint report full of old warnings is not this
branch's to fix, and fixing them buries the real diff.

## 3. Code sanitation checklist — on the diff

- No leftover debug output: stray `Log.*` or `println` added while debugging, commented-out code,
  dead code, unreachable branches.
- No `TODO` or `FIXME` introduced by this change, unless it names a tracked ticket.
- No unused imports, variables, parameters or functions. No wildcard imports.
- No hardcoded user-facing strings: define them in `res/values/strings.xml` and use `R.string.…`,
  **reusing an existing entry with the same text rather than adding a duplicate**. No hardcoded
  colours or dimensions the design system already defines.
- Consistent formatting: 4-space indent, no trailing whitespace, one trailing newline.
- The repository's own rules in `.ai/project/conventions.md` — read that file; it is the authority,
  not this one.

## Reporting

Report what ran and what was skipped, with the command output. **Never claim a clean lint without
it.** "ktlint is not wired into this project, so I applied its rules by hand" is a good line; a
silent pass is not.
