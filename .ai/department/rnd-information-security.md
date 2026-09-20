<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# R&D Information Security Policy

`/policies/information-security`, **active** 27 Aug 2026, binding on all of R&D. ISO: Ronnel Martinez, CTO. DPO: Atty. Mark Jim Ibus.

## Access
- Company Google Workspace identity. Least privilege, certified quarterly, revalidated on change for administrative access, removed on a move or a leave.
- **Developers hold no standing production access.** Production troubleshooting is driven by a DevOps engineer, session recorded.
- Credentials never shared. Two-factor mandatory on GitHub, before the organization invite and as a condition of membership.
- Preproduction and internal applications sit behind Cloudflare Zero Trust.

## Data
- Company and client data stays on company infrastructure.
- No exports or screenshots of production personal data without an approved reason.
- Classification: Public, Internal, Confidential, Restricted. KYC, financial, transaction, authentication, and regulatory investigation information is **Restricted**.

## Secrets
- Never commit secrets, credentials, tokens, or `.env` files.
- Approved stores only: GitHub Actions secrets, Bitwarden Secrets Manager, the Bitwarden vault, Cloudflare Secrets Store. Injected at deploy or run time, never in a document, chat message, or note file.
- Keys and certificates carry an owner, a rotation practice, and a recovery path reachable by more than one person. Certificates issue and renew automatically, not by hand.

## Logging
- Security-relevant events logged, retained 12 months with the most recent 3 immediately searchable, reviewed monthly by the ISO.
- Personal data, sensitive personal information, confidential information, production credentials, and account or payment data never reach a log, monitoring tool, error tracker, or alert.

## Vulnerabilities
- One process for findings from every source: found, ranked, owned, tracked, closed with evidence. Critical is patched the same day and interrupts sprint work; high is the first thing pulled into the sprint.
- Patching runs on the same severity clock. An actively exploited vulnerability goes ahead of any routine cycle.
- Independent VAPT by Secuna; scope agreed per engagement, report retained as evidence.
- Take routine dependency and platform updates regularly.

## Third parties
- New tools touching company data, code, or credentials are reviewed before use. Internal security documentation does not go on external SaaS.
- A provider holding our data, or sitting in a payment path, carries technical due diligence before, refreshed evidence during, and an exit that works.

## Incidents
Report a lost device, suspected compromise, or accidental exposure immediately. Clients and partners are notified within any window their agreement sets; assume 24 hours. Reporting does not wait on triage.