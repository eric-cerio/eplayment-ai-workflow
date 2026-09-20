# AI Context Structure

> Universal context file — read by Codex, Claude Code, GitHub Copilot, Cursor, Gemini, and all major AI coding agents.

<!-- AI_CONTEXT_STRUCTURE:START -->
- Before answering, planning, modifying files, generating code, proposing architecture/refactors, or suggesting tests, first read all requirements in this file and follow them strictly.
- Read `.github/ai-context-structure-instructions.md` first and follow everything in it.
- Read context in this order before any output:
  1. `.ai/company/`
  2. `.ai/department/` (when present)
  3. `.ai/project/`
  4. `.ai/features/` (when relevant)
- Always apply company policy, security guardrails, and review/ownership requirements before code, plans, architecture, refactors, or test suggestions.
- Keep this file as a short entrypoint and maintain detailed layered instructions in `.github/ai-context-structure-instructions.md` and `.ai/`.
- `.ai/company/` and `.ai/department/` are centrally managed and replaced on every sync. Repository-specific context goes in `.ai/project/` or `.ai/features/`, or below this block.
<!-- AI_CONTEXT_STRUCTURE:END -->

<!-- Only the AI_CONTEXT_STRUCTURE block above is managed: sync replaces it and preserves everything written below it. Add this repository's own instructions here. -->
