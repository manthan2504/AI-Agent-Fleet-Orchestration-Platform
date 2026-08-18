---
name: feedback-scope-docs-only
description: Design passes on this project default to documentation deliverables only — don't propose code packages, directories, or repo layout unless asked
metadata:
  type: feedback
---

When asked for a design/spec pass, deliver markdown ready to paste into the existing `docs/*.md` files — field tables, state diagrams, matrices, prose. Do **not** propose an executable artifact (a TS/Zod schema package, a `packages/` or `schemas/` directory, repo layout) unless the request explicitly asks for buildable code.

**Why:** on the 2026-08-18 Phase C pass I designed a `packages/contracts` Zod package as part of the entity-schema deliverable; the user narrowed scope mid-pass to documentation-only and dropped it. The project's docs are the source of truth (per CLAUDE.md), and the repo was still greenfield — there was no code for a shared package to serve yet, so the package was solving a problem that didn't exist at that point.

**How to apply:** when a task says "specify entities/schemas," default to a documentation section (field name, type, required/optional, one-line meaning) placed in the domain doc that already owns that concept — Task/TaskStatus in `docs/orchestration.md`, Agent/AgentStatus in `docs/runtime-agents.md`, Permission/ToolPolicy/ApprovalRequest in `docs/security-architecture.md`. Avoid new top-level doc files without a real reason. If a code artifact genuinely seems warranted, name it as an option and let the human decide rather than folding it into the recommendation. See [[project-task-lifecycle-refinements]] for what that pass produced.
