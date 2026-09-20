<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# R&D Acceptable Use Policy

`/policies/acceptable-use`, **draft** as of 3 Sep 2026: intent, not enforceable. Workstation conduct rules are on the handbook page; below is what bears on code and access.

## Credentials
- Company Google Workspace identity for company work. No personal accounts.
- Never share credentials, including with teammates. Whoever needs access gets their own.
- A unique password per account from the password manager, with two-step verification. No forced rotation; an immediate reset the moment there is reason to think one leaked.
- **Never commit secrets, credentials, tokens, API keys, keystores, signing certificates, or `.env` files.** Every platform and squad: a key in a mobile repository is as exposed as one in a service. Store them in an approved secrets manager, never a document, chat message, or note file.

## Network
Internal applications, preproduction, and infrastructure sit behind Cloudflare Zero Trust, not reachable from the open internet. Connected is not authorized: each resource decides. Do not bypass it, proxy around it, or share a session. Ask when legitimate access is denied.

## Data
Company and client data stays on company infrastructure: no personal cloud, email, or devices. No screenshots or exports of production personal data without an approved reason.

## Devices
A device holding company code or credentials runs CrowdStrike Falcon, in place before development begins, not disabled or excluded. Report a lost device, suspected compromise, or accidental exposure immediately.