# Security gate — the four layers

Recovered from `.github/pixel-workflows/security.md`, with the guarded-file list moved into each
repository's config and layer 4 written out for surfaces that have no `/security-review`.

Why it exists: this workflow generates code and then pushes it, in apps shipping native guards,
root and reverse-engineering detection, Play Integrity, certificate pinning and encrypted session
storage. A generated diff must be shown not to weaken any of that.

## What is reviewed

The changes on this branch: `git diff $(git merge-base HEAD <base_branch>)`, plus staged changes
and untracked files. Nothing to review → say so and stop.

Files listed in `security.known_tracked_secrets` are **already committed**. Report them once, as a
pre-existing issue needing rotation by the repository owner — never as a finding against this diff,
or every run fails forever on the same file.

## Layer 1 — hard rails

The paths in `security.guarded_files` may not change without the developer explicitly confirming
this diff should touch them. If the diff touches one, stop and ask before going further.

Always, regardless of config:

- No `versionCode` change (the hook denies it too).
- No force-push; no commit or push to a protected branch.
- No secret, keystore or credential committed: `*.jks`, `*.keystore`, `*.p12`, `*.pem`,
  `*credentials*.json`, `local.properties`, `keystore.properties`.

## Layer 2 — scan the diff

Each line here is a question to answer against the added lines, with what a finding looks like:

| Question | A finding looks like |
|---|---|
| Any hardcoded secret, API key, token or password? | a long opaque string literal assigned to a name like `KEY`, `SECRET`, `TOKEN`, or a base64 blob |
| Any personal data in logs? | `Log.d("…", user.email)`, phone numbers, tokens, full names, account or card numbers in any `Log.*` |
| New or changed manifest permissions? | an added `<uses-permission>`, especially location, contacts, SMS, storage, camera |
| New dependencies? | a line added to the version catalog or a `build.gradle` dependency block — who publishes it, and does the feature need it? |
| Token handling that bypasses the session layer? | a token read or written outside the encrypted session manager, or stored in plain `SharedPreferences` |
| Weakened pinning or integrity? | a removed or commented pin, a relaxed hostname verifier, `checkServerTrusted` left empty, an integrity or root check made non-blocking |
| Exported components? | `android:exported="true"` added on an activity, service or receiver without an intent filter that needs it |
| Insecure transport? | an `http://` URL, `usesCleartextTraffic`, a network security config relaxed |

## Layer 3 — audit the hardening

Confirm the change does not weaken what the app already has:

- Tokens still flow through the encrypted session manager.
- New API calls carry their auth header.
- Integrity, root-detection and reverse-engineering paths are untouched.
- No new networking that bypasses the pinned client.
- Nothing security-relevant moved from native code into Kotlin, where it is easier to patch.

## Layer 4 — review

Where the surface offers a built-in security review (the CLI's `/security-review`), run it on the
diff so findings stay consistent with the rest of the organisation, and fold its output in.

Where it does not (Android Studio), work through layers 2 and 3 as a deliberate second pass rather
than skipping layer 4: re-read the diff as someone trying to find a way in, not as its author. Say
in the report which of the two you did.

## Severity

| Level | Meaning |
|---|---|
| **High** | a secret in the diff, personal data in logs, weakened pinning or integrity, a guarded file changed without confirmation, a new dangerous permission, cleartext transport |
| **Medium** | a new third-party dependency, a newly exported component, a broadened scope, logging that could become personal data |
| **Low** | style and hygiene with a security flavour: a `TODO` about auth, an unused permission left behind |

**High severity blocks the push.** Fix it, or the developer waives it with a written reason.

## Waivers

A waiver is the developer's decision, never the skill's:

- Record it in the ticket file under `security.waivers` with the finding and the reason, verbatim.
- Set `security.result: waived`.
- It is tied to the current diff fingerprint, so it expires the moment the code changes.
- Repeat every waiver in the stage 09 summary, so the reviewer of the PR sees what was waived.

Never invent a reason, never waive on your own initiative, and never record a waiver the developer
did not give in words.

## Reporting

Group findings by severity, each with `file:line` and the fix. Then write the result to the ticket
file: `result`, the `diff` fingerprint (see `shared/ticket-file.md`) and any waivers. End with one
line stating whether the push is clear.
