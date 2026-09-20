<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# Security Guardrails

AI output is untrusted until validated. Treat it with the same or greater scrutiny than manual code. Humans own security; AI never owns a risk decision. The author owns correctness, security, and final validation.

What never goes into a prompt is in `ai-usage-policy.md`.

## High-risk areas: extra review
Auth/authz, secrets, crypto, data handling, external calls, trust boundaries, infra/CI, network exposure, production writes, migrations, logging/telemetry, compliance-sensitive flows.

## Minimum review questions
- Does this expose or move sensitive data?
- Does it weaken auth, authz, isolation, or least privilege?
- Does it add secrets, unsafe defaults, or new trust boundaries?
- Does it bypass validation, monitoring, or approval gates?
- Does it create new attack paths or worsen existing ones?

## Prohibited
- Applying AI code without human review
- Prompting with secrets or sensitive data
- Accepting an unsafe AI suggestion because it seems plausible
- Skipping tests, scans, or evidence-based validation

## Validation
- Verify AI claims against code, tests, and runtime evidence.
- Re-review any security-sensitive change before merge.
- Escalate uncertainty, high-risk changes, or unresolved concerns to R&D before merge or deploy.