---
name: project-operations-open-question-premise
description: The "Operations agent" open decision cites overview.md §1 as listing Operations — that citation does not hold up; verify before anyone tries to close it
metadata:
  type: project
---

`docs/runtime-agents.md` §3.3 carries an open question stating that "the spec's Purpose section (§1) lists **Operations** as one of the fleet's organizational roles, but Operations doesn't appear in the Agent Registry." As of 2026-08-18, `docs/overview.md` §1 (Purpose) does **not** mention Operations anywhere, and neither does §2's fleet listing. A grep across `docs/` finds the word only in that open-question note itself and in a `roadmap.md` back-reference.

**Why:** this matters because the open decision's entire premise is a registry-vs-Purpose-section discrepancy. If the Purpose section never listed Operations in this repo's version of the spec, the discrepancy may only exist in an upstream source document that was never transcribed — which changes the question from "was Operations dropped by mistake?" to "did it ever exist here at all?"

**How to apply:** do NOT resolve this. Operations placement is one of three items CLAUDE.md explicitly reserves for the human owner (alongside vector-DB technology and ADR numbering), and the user has been explicit that agents surface these rather than decide them. Surface this citation problem *with* the question so the human is deciding on accurate information — the fix may be as small as correcting the note's citation rather than adding or dropping an agent. Related: [[project-task-lifecycle-refinements]].
