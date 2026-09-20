# Per-repository configuration

Every skill in this workflow reads `.ai/project/android-workflow.yml` from the repository it is
working in. **No skill contains a repository name, path, Gradle task or version rule** — those live
here, so the same plugin serves every Android repository.

`.ai/project/` belongs to the repository. `epm aics sync` replaces `.ai/company/` and
`.ai/department/` wholesale, so nothing this workflow needs may live in those two.

## Missing config

If `.ai/project/android-workflow.yml` does not exist, **stop** and tell the user to run
`/android-onboard`. Do not guess the values and do not fall back to defaults for the repo-specific
keys.

## The file

```yaml
workflow_version: 0.1.0                 # plugin version this config was written for
app_tag: PIXEL                          # stage 10 header: [...][PIXEL]
jira_base: https://eplayment.atlassian.net/browse/
base_branch: develop
protected_branches: [develop, main, master]

build:
  gradle_file: app/build.gradle
  jdk: 17                               # minimum; resolved at run time, see below
  lint_task: lintDebug
  test_task: testDebugUnitTest
  ktlint: none                          # none | gradle | cli

versioning:
  rule: patch-bump                      # patch-bump | branch-suffix

release_notes:
  file: FirebaseAppDistributionConfig/release_notes.txt
  mode: append                          # append (skip duplicates) | replace

distribution:
  register_branch_in: none              # or a workflow file whose push.branches gets this branch
  open_draft_pr: true                   # offer the draft PR after a successful push

bugfix_branch_rule: ask                 # ask | batch | per-ticket

lint:
  post_edit_checks: []                  # scripts the post-edit hook runs, advisory

security:
  guarded_files: []                     # may not change without explicit confirmation
  known_tracked_secrets: []             # already in git; reported once, never a per-run failure
```

## Defaults

A missing key takes its documented default; an unknown key is ignored, so an older plugin keeps
working against a newer config.

| Key | Default |
|---|---|
| `jira_base` | `https://eplayment.atlassian.net/browse/` |
| `base_branch` | `develop` |
| `protected_branches` | `[develop, main, master]` |
| `build.jdk` | `17` |
| `build.ktlint` | `none` |
| `versioning.rule` | `patch-bump` |
| `release_notes.mode` | `append` |
| `distribution.register_branch_in` | `none` |
| `distribution.open_draft_pr` | `true` |
| `bugfix_branch_rule` | `ask` |
| `lint.post_edit_checks`, `security.*` | empty |

`app_tag`, `build.gradle_file`, `build.lint_task`, `build.test_task` and `release_notes.file` have
**no defaults**. Without them, stop and send the user to `/android-onboard`.

## Finding the JDK

Never hardcode a JDK path — it is different on every machine. Resolve it in this order and use the
first that satisfies `build.jdk` (that version or newer):

1. `$JAVA_HOME`
2. `/usr/libexec/java_home -v <build.jdk>+`
3. Android Studio's bundled runtime: `/Applications/Android Studio.app/Contents/jbr/Contents/Home`

If none qualifies, say so and stop rather than running Gradle on an unknown JDK. Pass the result as
`JAVA_HOME` to every Gradle command.

## Version drift

`workflow_version` records the plugin version that wrote the config. If the installed plugin is
older, print one line — "this repo expects android-workflow `<x.y.z>`; run `copilot plugin update`"
— and **carry on**. Drift never blocks a run.
