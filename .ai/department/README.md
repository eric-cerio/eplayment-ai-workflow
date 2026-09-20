<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# Department context: R&D

R&D policies from the R&D Handbook (`https://rndhb.eplayment.app`), mirrored 3 Sep 2026. This layer may add to `.ai/company/`, never weaken it; company policy wins a conflict.

Status decides force. `active` binds. `draft` is written but not ratified: follow as intent, do not enforce it or present it as settled, and say which when it decides an outcome. The handbook page is authoritative: append `.md` to its URL, or use the handbook MCP server.

Read `rnd-squad-standards.md` plus the file the task touches, not all of them.

| File | Page | Status | Read for |
|---|---|---|---|
| `rnd-squad-standards.md` | `/standards/` | Draft | Any code, plan, or review: which squad's standards apply |
| `rnd-ai-use.md` | `/policies/ai-use` | Draft | AI-assisted work, agents, workflows, real data in development |
| `rnd-information-security.md` | `/policies/information-security` | **Active** | Auth, access, secrets, logging, dependencies, vendors |
| `rnd-privacy.md` | `/policies/privacy` | Draft | Schemas, log lines, seed data, retention, deletion, exports |
| `rnd-development-lifecycle.md` | `/policies/development-lifecycle` | Draft | Branching, review, release, deploy, change control |
| `rnd-acceptable-use.md` | `/policies/acceptable-use` | Draft | Credentials, secrets in a repo, network access |

A policy binds all of R&D. A standard is technical, per squad, owned by the squad head. `.ai/project/` and `.ai/features/` must not weaken this layer. Keep digests to the R&D delta; do not restate `.ai/company/`.