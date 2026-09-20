<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# R&D Development Lifecycle Policy

`/policies/development-lifecycle`, **draft** as of 3 Sep 2026: intent, not enforceable. Gates, environments, and change-control steps still need R&D sign-off; TBD items are unsettled.

Covers all software R&D builds or operates. `eplayment-labs` experiments are out until promoted toward production. How much of the control set a system carries depends on its tier in `/standards/engineering/scope`.

Environments: local (the developer), preproduction (integration and QA, behind Cloudflare Zero Trust), production (restricted, changes controlled).

1. **Plan**: a Jira ticket meeting the Definition of Ready.
2. **Build**: a branch cut from `develop`, GitFlow via HubFlow. Backend follows Pint, Larastan, structure, and security; anything exposing or consuming an API follows the API Contract; data changes follow the database standards.
3. **Test**: tests written with the change. QA owned by SQA, in preproduction.
4. **Review**: every change reaches `develop` through a pull request approved by the owning squad head. Backend also passes its pre-PR checklist. CI runs on every pull request.
5. **Release**: semantic versioning, the release and hotfix process, release notes.
6. **Deploy**: approval, testing, rollback, and the per-change record are in `/standards/engineering/change-management`. Mechanism per environment is TBD.

Production changes need approval from someone other than the author. Not finished until it meets the Definition of Done.