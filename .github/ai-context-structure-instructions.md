# AI Context Structure Instructions

Use the layered AI context in this repository as your source of truth.

Before generating code, making a plan, proposing architecture/refactors, or suggesting tests:

1. Read `.ai/company/` first, including `.ai/company/ai-instructions.md`.
2. Then apply `.ai/department/` for department-level policies when present, including `.ai/department/rnd-squad-standards.md` to resolve which squad standards apply.
3. Then apply `.ai/project/` for repository-specific context.
4. Then apply `.ai/features/` for feature/module-specific context when relevant.

Priority rule: narrower scope may add details but must not weaken broader-scope rules.

Before producing code or plans, align with:

- `.ai/company/ai-usage-policy.md`
- `.ai/company/security-guardrails.md`
- `.ai/company/review-and-ownership.md`

Policy binds. A standard binds only where its source page status is `active`; check before enforcing one or presenting it as settled.
