---
name: ticket
description: Run the full Android feature workflow for a Jira ticket - intake and plan, branch, optional implementation, then lint, version, tests, code review, security gate, commit and push, and the distribution note. Use when the user gives a Jira key to work on, says they want to start a ticket or a feature, or types /ticket.
---

# /ticket — the feature workflow

Read `shared/ticket-file.md` first.

> **Finding these files:** they live in the **plugin root** — the nearest ancestor directory of
> this skill file that contains `plugin.json`. Locate that directory first, then read
> `<plugin-root>/shared/<file>.md`. They are not in the repository you are working in, and not
> under `skills/`. If you cannot find them, say so and stop rather than continuing without them.

**Resume before you start.** A ticket file for this key already exists → begin at the first
unfinished stage and say where you resumed from. An approved plan from yesterday is not re-asked.

1. **`android-plan <KEY> feature`** — gate 1. Wait for the go.
2. **`android-branch`**
3. **Ask Y / N: should the development skill write this?**
   - **Y** → `android-develop`
   - **N** → stop here and print: *"Write the code, then run `/android-ship`."*
     N is a legitimate answer. Do not argue with it, do not ask twice, and do not start writing
     anyway. Every stage after this one behaves identically either way.
4. **`android-ship`** — stages 05 to 10 with the 07b code review, and gates 2 and 3
   inside it.

Never inline stages 05–10 here; `android-ship` owns them. Never skip a gate to save a round trip.
