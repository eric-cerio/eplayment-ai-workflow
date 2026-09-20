# Distribution test note — rules

Recovered from `.github/pixel-workflows/distribution-note.md` (the last complete module set), with
the app tag and the release-notes path replaced by configuration.

Final step of both workflows — runs **after the branch is pushed** (stage 10). Produces a
copy-pasteable test-distribution announcement for testers. **Output only: this step touches no
files and no git.**

## Steps

1. **Ask: PROD or QA testing?** Two options, nothing else in this skill asks anything.
   - Prod → leading tag `[FOR PROD TESTING]`
   - QA → leading tag `[FOR QA TESTING]`
2. **Read the version** from `build.gradle_file`: `versionName` and `versionCode` → format as
   `<versionName> (<versionCode>)`.
3. **Read the Jira URLs** from `release_notes.file` — every line, in file order. That file is the
   accumulated build's release notes, so it may list tickets from several branches. That is correct:
   the note describes the build, not one ticket.
4. **Emit the block** in a fenced code block for copy/paste: the header line, then one Jira URL per
   line.

## Header format

```
[FOR <PROD|QA> TESTING][Android][<versionName> (<versionCode>)][<app_tag>]
```

`<app_tag>` comes from the repository's `.ai/project/android-workflow.yml`.

## Worked example

With `app_tag: PIXEL`, `versionName "3.3.14"`, `versionCode 52`, and a release-notes file holding
`TA-5229` and `TA-582`:

```
[FOR PROD TESTING][Android][3.3.14 (52)][PIXEL]
https://eplayment.atlassian.net/browse/TA-5229
https://eplayment.atlassian.net/browse/TA-582
```

Choosing QA flips only the first tag to `[FOR QA TESTING]`; everything else is identical.

## Rules

- Present the block for the user to copy. Do **not** write it to a file or post it anywhere.
- Do not reformat, sort or deduplicate the Jira URLs; file order is the build's order.
- An empty release-notes file means the build has no tickets recorded. Say so rather than emitting
  a header with nothing under it.
- `versionCode` is read here, never written. Stage 06 does not set it either; CI and release own it.
