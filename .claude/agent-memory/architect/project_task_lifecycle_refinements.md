---
name: project-task-lifecycle-refinements
description: Two unresolved semantic issues in the committed Phase C task lifecycle — approval-rejection mapped to CANCELLED, and TIMED_OUT duplicating an existing failure-type dimension
metadata:
  type: project
---

Phase C (2026-08-18) added `CANCELLED`, `TIMED_OUT`, `DEAD_LETTERED`, `PARTIALLY_COMPLETED`, and `PENDING_APPROVAL` to the task lifecycle in `docs/orchestration.md` §4.4.2. Two design points were raised after the fact and are **not** resolved:

1. **Rejection mapped to `CANCELLED`.** §4.4.2 currently says `PENDING_APPROVAL` "moves to `CANCELLED` on rejection." A human rejecting a gated action (`security-architecture.md` §8.7) is a policy decision, not a cancellation. §4.6 already has a `Policy rejection` failure type that fits exactly. Conflating the two makes "a human said no" indistinguishable from "someone called the task off" in audit trails and failure metrics.
2. **`TIMED_OUT` duplicates an existing dimension.** §4.6 already classifies `Timeout` as one of eight failure *types* carried in the task's Error Information field. Modelling it as a separate lifecycle *state* means every consumer must handle "failed or timed out" everywhere a terminal failure is checked. The alternative was `FAILED` + `errorType: TIMEOUT`.

**Why:** these were flagged rather than fixed because the docs were already written and committed by the main thread, and neither is a correctness bug — both are legibility/auditability trade-offs the human owner may reasonably accept as-is.

**How to apply:** raise these if the task state machine is revisited (Phase 4 builds the durable queue, retries, and timeouts per `docs/roadmap.md` — that is the natural moment). Do not silently rewrite §4.4.2 to "fix" them. Note also that `docs/orchestration.md` §4.4.3 still links to `memory-and-observability.md`, which does not exist — the real files are `memory.md` and `observability.md`. Related: [[feedback-scope-docs-only]].
