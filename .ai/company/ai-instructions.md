<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# AI assistant execution standard

Read context in this order before any output:
1. `.ai/company/`
2. `.ai/department/` (when present)
3. `.ai/project/`
4. `.ai/features/` (when relevant)

Always read relevant context before generating code, making a plan, proposing architecture, writing refactors, or suggesting tests.

Priority and behavior:
- company context is highest priority
- department context sits between company and project; it may add policies but must not weaken company rules
- project context defines repo-wide conventions and architecture
- feature context defines narrow module/workflow details
- do not bypass or weaken company policy, security guardrails, or review/ownership rules
- do not invent missing policy; ask for clarification
- enforce human-led, AI-assisted development and required review ownership

Binding vs advisory:
- policy binds; a standard binds only where its source page status is `active`
- treat a `draft` standard as intent, not a requirement, and say which when it decides an outcome