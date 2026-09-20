<!-- Managed centrally by ai-context-structure. Do not edit: the next sync replaces this file. Project context belongs in .ai/project/ -->

# R&D Privacy Policy

`/policies/privacy`, **draft** as of 3 Sep 2026, pending DPO review: intent, not enforceable.

DPO Atty. Mark Jim Ibus owns the legal position, NPC filings, breach determinations, and judgment calls. ISO Ronnel Martinez (CTO) owns the technical controls. Ask the DPO rather than deciding a privacy question in a pull request.

Every design satisfies all three at once: transparency (the person knows), legitimate purpose (lawful and declared), proportionality (least data that achieves it).

## Collect less
- Per personal data field, answer: what breaks if this is not collected? "Nothing yet" means it does not go in.
- A field with no live consumer is a liability: still secured, retained, disclosed, and deleted on time.
- Prefer a reference to a copy. Do not persist a field needed only momentarily.

## Sensitive personal information
- Not introduced without the DPO agreeing first, including "because KYC will need it".
- Where required: encrypted, access narrower than the rest of the record, reads logged as sensitive access.
- A scanned ID is sensitive personal information.

## Privacy by design
Review before the build, not before launch. A Privacy Impact Assessment by the DPO for a new system or a material change to what one collects. A new third party is reviewed before anything is sent. **A new purpose for data already held is a new collection**, even with no new field.

## Non-production
Production personal data does not go into a non-production environment.
- Generate seeded or synthetic data. Not a production dump, not a hand-sanitized copy.
- A masked or tokenized extract only where realism is genuinely required and the DPO has agreed it.
- Reproduce from an identifier through the proper path rather than copying a record out locally.

## Logs
Personal data never reaches a log, monitoring tool, error tracker, alert, dashboard, analytics event, or chat integration.

## Retention and deletion
- Kept only as long as the declared purpose needs, then deleted or anonymized. Periods set per system with the DPO and documented with the system.
- Deletion has to be something the system can actually do.
- Deletion reaches backups, exports, caches, search indexes, and downstream duplicates. Deleted from the primary store and left in an index is not deleted.
- Transaction records under a statutory record-keeping obligation have their own period.

## Rights of the person
R&D builds the systems that make answering requests possible: from an identifier, records can be found across every system holding them, exported in a usable form, corrected without a manual database edit, and deleted or blocked including downstream copies. A system that cannot do one of these has a defect worth recording.

## Third parties
DPO review and a written agreement before anything reaches a processor, including anything receiving data incidentally: error trackers, analytics, support tools, AI services. Storage or processing outside the Philippines needs the DPO in advance.

## Breach
Report at suspicion, to the ISO and the DPO, without investigating quietly first: the NPC clock runs from knowledge or reasonable belief. The DPO decides whether it is notifiable and makes any notification. Never help conceal an incident.

## Records kept
Privacy Impact Assessments per system; retention periods plus evidence of deletion runs; the register of third parties receiving personal data; breach reports and DPO determinations.