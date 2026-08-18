---
name: docs-cross-references
description: Recurring convention (and recurring slip) in this project's docs/ set around referencing section numbers across files.
metadata:
  type: project
---

Convention actually used across `docs/*.md`: a section reference to a *different* file is written qualified, e.g. `` `security-architecture.md` §8.7 ``. A bare `§8.7` with no filename is only correct when it resolves within the current document's own numbering.

Found one real slip of this kind in commit bc14990 (2026-08-18): `docs/orchestration.md` line 131 used a bare `§8.7` inside an ASCII diagram comment, referring to `security-architecture.md`'s Human Approval section — orchestration.md has no `§8.x` sections of its own (all its sections are `§4.x`). The correctly qualified form appears three lines later in the same file, so this was inconsistency within one file, not a systemic pattern — flagged as a Warning, not a blocker.

**When reviewing new docs commits:** grep the touched file's own headers first (`^## \|^### `) so you know its own numbering prefix (e.g. orchestration.md = `4.x`, security-architecture.md = `8.x`, api.md = `11.x`, runtime-agents.md = `3.x`, observability.md = `10.x`, memory.md = `6.x`, workflow.md = `5.x`, runtime.md = `7.x`). Any `§N.M` in the diff where `N` doesn't match the current file's own prefix must carry a filename qualifier — flag it if it doesn't.
