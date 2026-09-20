<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# R&D AI Use Policy

`/policies/ai-use`, **draft** as of 3 Sep 2026: intent, not enforceable. R&D layer under `.ai/company/ai-usage-policy.md`; adds only, never relaxes. Delta only below.

Approved: GitHub Copilot in-IDE; Claude and Gemini outside the IDE, company accounts. Anything else needs approval first. Requests and questions go to `#ai-requests` on Discord.

## Development tool vs in-product
- A system shipped through the normal process (version control, code review, CI, security review, change management) is governed by those standards whether or not AI wrote the code. Copilot on a pull request does not create an Agent.
- That covers AI as a development tool only. A system that calls a model at run time, or sends company, client, or personal data through an AI service, is in scope in full.

## Vibe-coded and AI-assisted systems
- The test is the process, not the department. Skipped code review means in scope, including inside R&D.
- Reviewed before production or exposure to real users or real data: security (injection, secrets handling), data flows, error handling, maintainability.
- Company-managed infrastructure only.
- In production or with real data it is an Agent, as is an AI-assisted script others use or that touches company data.

## Approvals
- R&D holds Technical Approval for every department. Not waivable by Business Approval, a department head, or the AI Enablement Task Force. Final authority: the CTO, who also gives Business Approval within R&D.
- Where the system owner sits in R&D, someone else reviews.
- An AI Use Compliance review is required before production or real data, on top of the technical review.
- DPO referral only on a company escalation trigger: high-risk personal data, a new category or purpose, a new vendor or a transfer outside the Philippines, an automated decision materially affecting someone, or AI in a customer-facing payments decision. Otherwise R&D approves and records why.

## Real data in development
R&D adds a seventh condition to the company's six: the DPO has agreed it.