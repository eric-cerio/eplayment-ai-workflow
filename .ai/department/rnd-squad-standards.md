<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# Squad standards

`/standards/`. Standards are technical, owned by the squad head, and not copied here. Resolve which apply from the R&D Handbook MCP server (`https://rndhb.eplayment.app/mcp`): the connection is per-person and carries squad membership.

Resolve once per session, before code, plans, architecture, refactors, or tests.

1. Take the current identity: session user email or GitHub username, else `git config user.email`.
2. `lookup_person` returns their squads and `owns_paths`, the standards those squads own.
3. `list_squads` is the authoritative squad-to-standards map.
4. `get_page` the section index first (for example `/standards/backend/`), then only the pages the work needs.

No identity, or `squads: []` (how leadership and cross-functional roles resolve): do not guess a squad. Fall back to the domain of the files being changed, and say which standards you applied and on what basis. Work crossing squads takes every crossed squad's standards.

| Squad | Head | Owns |
|---|---|---|
| Backend | Davidson Ramos | `/standards/backend/`, `/standards/database/`, `/standards/engineering/api/` |
| Frontend | John Allen De Chavez | `/standards/frontend/` |
| iOS | Milky Joy Agora | `/standards/ios/` |
| Android | Rey Robert Castro | `/standards/android/` |
| DevOps | Benjamin Perez | `/standards/devops/`, `/standards/engineering/git-workflow/` |
| UI/UX | Jasper Caparas | `/standards/ui-ux/` |
| SQA | John Smith Bitong | `/standards/sqa/` |

`/standards/engineering/` outside `api/` and `git-workflow/` is cross-cutting and applies to every squad.

Check `status` on each page: `active` binds, `draft` is intent you do not enforce, `not-started` has no content to follow. As of 3 Sep 2026 no standard is ratified (`enforceable_page_count: 0`), so a standards-based review comment is a suggestion and must say so. A standard never lowers a policy rule.

Quote the page path and its status. Do not paraphrase a standard into a rule it does not state, or present a general best practice as ours. Squad heads approve pull requests in their area; use `lookup_person` to route a review rather than guessing.