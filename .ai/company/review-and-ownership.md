<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# Review and Ownership

Humans own the work. AI can draft; authors and reviewers remain accountable.

## Author
- Must understand, explain, and defend the change, and owns correctness, safety, tests, docs, and follow-up.
- Before review: own the diff end to end, run the needed checks, document assumptions and known limits, resolve obvious issues first.
- Before merge, explain what changed, why, the expected behavior impact, the risks, edge cases, and tradeoffs, and the evidence used to validate it.

## Reviewer
- Understand the diff, not just the summary.
- Challenge unclear logic, hidden behavior, or unsupported claims.
- Do not substitute AI output for your own judgment.

## Red flags
Author cannot explain the change; missing or weak validation; a large unreviewable diff; hidden AI-generated behavior; unclear ownership or follow-up; security, data, or compliance risk.

## No merge
- Until the author can explain the change and reviewers are satisfied.
- With open critical issues, unresolved ownership, or missing validation.

Non-compliant work is returned for rework. Block the merge where ownership or explainability is missing, and escalate repeated or intentional bypasses.