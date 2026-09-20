# `.ai/` layers: where your context belongs

Two of these layers are replaced on every sync. Two are yours.

| Layer | On `epm aics sync` / `./sync.sh` |
|---|---|
| `.ai/company/` | **Replaced wholesale.** Local edits discarded, files dropped upstream deleted |
| `.ai/department/` | **Replaced wholesale.** Same |
| `.ai/project/` | **Never touched.** Yours |
| `.ai/features/` | **Never touched.** Yours |

**Adding context for this repository: put it in `.ai/project/`, or `.ai/features/` if it only describes one module or workflow.** Anything you write in `company/` or `department/` is gone at the next sync, without a prompt and without a diff.

The entry-point files (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`) are a third option: only the `AI_CONTEXT_STRUCTURE` block at the top is managed, and anything you write below it is kept.

`.github/ai-context-structure-instructions.md` is replaced outright. Never hand-edit it.

Reading order is company, department, project, features. A narrower layer may add detail but must never weaken a broader one.
