# Detecting a repository's conventions

How to fill in each key of `.ai/project/android-workflow.yml`. Read the repository rather than
asking, wherever the repository can answer. Ask only for what it cannot.

State plainly which values you **detected** and which you are **guessing**, and let the developer
correct either.

## Build

| Key | How to detect |
|---|---|
| `build.gradle_file` | the first of `app/build.gradle`, `app/build.gradle.kts` that exists. A repo with no `app` module: find the module applying `com.android.application` |
| `build.lint_task` | the build types in that file. A `debug` block gives `lintDebug`. With product flavors, the task is `lint<Flavor><BuildType>` — ask which variant is the default |
| `build.test_task` | the same: `testDebugUnitTest`, or `test<Flavor>DebugUnitTest` with flavors |
| `build.ktlint` | `grep -rl ktlint --include='*.gradle*' .` → `gradle`; else `command -v ktlint` → `cli`; else `none` |
| `build.jdk` | `17` unless the project says otherwise (`jvmToolchain`, `sourceCompatibility`, a CI workflow's `java-version`) |

Confirm the two task names by listing them rather than trusting the parse:

```bash
./gradlew -q tasks --all 2>/dev/null | grep -E '^(lint|test).*' | head -20
```

If Gradle cannot run (no JDK, a broken build), say so and take the names from the build file.

## Versioning

Read the history of the Gradle file and look at what happened to `versionName` on feature branches:

```bash
git log -p --all -- <gradle_file> | grep -E '^[+-].*versionName' | head -40
```

- Lines like `- versionName "2.13.9"` / `+ versionName "2.13.9-some-branch-topic"` → `branch-suffix`.
- Lines where only the last number moves (`3.4.27` → `3.4.28`) → `patch-bump`.
- Both present: the **feature-branch** commits decide it. Release commits on the base branch bump
  the version for a different reason.

## Release notes

```bash
git ls-files | grep -i release_note
git log -p -- <that file> | head -60
```

- Commits that only add lines → `mode: append`.
- Commits that replace the file's contents with one branch's ticket → `mode: replace`.

## Distribution

Look for a workflow whose `push.branches` lists anything besides the base branch:

```bash
grep -rn -A3 'on:' .github/workflows/*.yml | grep -A2 'push:' | grep 'branches:'
```

A list like `[ develop, feature/some-work ]` means feature branches get registered there to
trigger a build → set `distribution.register_branch_in` to that file. A list of only the base
branch means `none`.

With **exactly one** extra branch, say so as a guess rather than a detection: one branch may have
been added by hand for a single build rather than as a convention.

## Security

```bash
git ls-files | grep -Ei '\.(jks|keystore|p12|pem)$|credentials.*\.json$|^local\.properties$'
```

Everything that comes back is **already committed**, so it goes in `known_tracked_secrets`: the
gate reports it once as a pre-existing issue instead of failing every run. Say plainly in the
summary that these files are in git history and need rotating — that is the repository owner's
call, not this skill's.

For `guarded_files`, list what must not change without explicit confirmation. Look for: native
sources under `src/main/cpp`, anything named for integrity, attestation, root or reverse-engineering
detection, certificate pinning, the signing config, and the Gradle file itself. Present the list for
confirmation rather than inventing a long one.

## The rest

| Key | Value |
|---|---|
| `app_tag` | **Always ask.** Suggest the last segment of `applicationId`, uppercased |
| `jira_base` | `https://eplayment.atlassian.net/browse/` |
| `base_branch` | `develop` if it exists, else `main`, else `master` |
| `protected_branches` | always `[develop, main, master]` plus `base_branch`. **Do not filter to branches that exist today** — one created later would otherwise be unprotected. The hook also unions this list with those three, so narrowing it cannot unprotect them |
| `bugfix_branch_rule` | `ask`, unless the repo's `bugfix/*` branches are clearly all one shape |
| `workflow_version` | the `version` field of the plugin's own `plugin.json` |

## Drafting the architecture docs

Only when `.ai/project/architecture.md` or `conventions.md` are missing. Read the code, do not
generalise from a framework blog:

- The layering actually used, named after the real classes (`ViewModel → UseCase → Repository →
  Api`, or whatever is there).
- MVVM or MVI per area, with the file you concluded it from.
- The design-system widgets, named.
- Error handling: the result or response wrapper, and whether `try/catch` is the convention.
- The test style already in `src/test`.

Head each drafted file with:

```
> Draft, written by /android-onboard — review before relying on it.
```

## Legacy files to report

Do not delete anything. Report:

- `.github/prompts/*.prompt.md` that reference `.ai/department/` modules — those modules are
  replaced by `epm aics sync`, so those prompts are broken.
- Symlinks under `.claude/` or `.github/` whose target does not exist.
- A `sync.sh` or workflow module folder superseded by this plugin.
