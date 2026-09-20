<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# AI Usage Policy

Company-wide, and the floor: no lower layer weakens it. Covers assistants, AI features inside SaaS, internal tools or agents that call models, and AI automations.

## Data levels
| Level | Content | Where |
|---|---|---|
| L1 | General knowledge only. No company, client, or partner material | Any approved tool. Personal accounts are L1 only |
| L2 | Company information; personal data not the subject | Approved tools, company accounts |
| L3 | Personal data as the subject | Approved tools, company accounts, DPO first |

Never use a tool above its approved level. Unsure: treat it as the higher level.

## Never enter into any AI tool
Personal data, sensitive personal information, confidential company/client/partner information, production credentials (keys, passwords, OTPs, tokens, certificates), customer account numbers, government IDs, KYC documents. Offer masked or sample data instead. If a live credential is pasted: stop, say to remove it, say to have it rotated.

Only exception: a specific use pre-approved with safeguards.

## Tools
- Company work runs in company AI accounts on company infrastructure.
- Personal accounts: L1 only. The test is what you enter, not what you ask. Attaching code, data, a document, or a screenshot makes it company work.
- Unapproved tools are prohibited for anything touching company data or work product.

## Tiers
| Tier | What it is | Approval |
|---|---|---|
| App | Off-the-shelf tool used directly by a person | Only if not already approved |
| Workflow | Automation with an AI step, triggered by a person or a schedule | Before use |
| Agent | Autonomous: chooses actions, holds credentials, calls tools, or writes to systems of record | Before any use with real data |

Where something could be two tiers, the higher applies. A vibe-coded system in production or with real data is an Agent.

Agents also require company-managed hosting, least-privilege credentials never shared and never a human user's, a named individual owner, an off switch that needs no code deploy, and reassignment or decommission within 30 days if the owner leaves or changes role.

## AI and Agents Registry
Every App, Workflow, and Agent is recorded at build time, before anyone but the author uses it. Registering something unapproved is not a violation; using it unapproved is.

Entry: name, tier, owner, department, tool or model, data category, approval status, last review, and for personal data the DPO determination or a note that no trigger was met.

## Approvals
Business Approval (whether to adopt) and Technical Approval (whether it is safe against company systems and data) are separate, and neither substitutes for the other. R&D is the technical gate for every department.

Ask Joe Josue for AI tool approval, the DPO for privacy, R&D for technical review.

## Real data in development
Synthetic or masked first. Real data only under all of: minimum volume, approved AI service, no production write access, company-managed device, untested fields masked, deleted before approval. High-risk personal data needs the DPO first at any volume.

## Output
Verify AI output independently, especially legal, financial, security, and compliance content. Check generated content against third-party IP before shipping. You own what you enter, what you approve, and what you ship.

## Incidents
Report a lost device, suspected compromise, or data exposure immediately, at the point of suspicion. Prompt disclosure is a mitigating factor. Never help conceal an incident.