---
name: approval-gate-design-gaps
description: Confirmed design-level gaps in the Human Approval gate (security-architecture.md §8.7/§8.7.1, orchestration.md §4.4.2/§4.6, api.md §11.7) found in the 2026-08-18 docs audit — re-check before the gate is implemented.
metadata:
  type: project
---

Audited 2026-08-18 (docs-only, commits bc14990/966c8de/12c6ca1). No running code, so nothing was Critical; these are all "High if implemented literally as specified."

Confirmed open (as of that date, unfixed — audit only, no changes made):

1. **Rejected approval is retry-eligible.** `PENDING_APPROVAL` + rejection → `FAILED` (`Policy rejection`), but orchestration.md §4.6's new line makes every non-`Permanent` failure eligible for `RETRY`. `Policy rejection` is a *separate* failure type from `Permanent` in §4.6's table, so a human "no" is retryable. Contradicts §8.7's "full stop, no fallback path."
2. **Approval timeout has two conflicting lifecycle targets.** §8.7.1 says timeout → task `FAILED`/`Policy rejection`; §4.6 says a Timeout failure → task `TIMED_OUT` (retry-eligible). Fail-closed holds on "never auto-approves" but not on terminality.
3. **No binding between the approval and the executed call.** `ApprovalRequest` has free-text `action`, no `tool_id`/`tool_call_id`/params hash. TOCTOU + the human sees agent-influenced text, not the real call.
4. **No documented human-vs-agent principal split.** `/approvals/{id}/approve` sits behind the same `Authorization: Bearer` convention as every other endpoint; `resolved_by` is typed "user ID" with nothing enforcing human-ness or approver ≠ requester.
5. **`403 if not the designated approver` is unimplementable** — no approver field exists on the entity.
6. **`allowedDecisions: "allow-always"`** in OpenClaw's `requireApproval` (see [[openclaw-trusted-tool-policies]] in the researcher's memory) would convert §8.3.1's "approval every time" into a standing grant. Not mentioned in §8.3.2's grounding note.
7. **Idempotency-Key scope unspecified** (api.md §11.1.1) — if cached on the key alone rather than (actor, endpoint, resource, body), a reused key can return a cached APPROVE for a different approval/endpoint.
8. **No `approval.timed_out` or policy-denial event** in observability.md §10.4's event table — the fail-closed path is invisible to audit.

**Why:** these were introduced/exposed by the Phase-C doc pass that rendered the permission matrix and entity specs for the first time; the phrasing reads as settled but requires code enforcement to actually hold.

**How to apply:** treat 1, 2, 3, 4 as blocking design questions before any Tool Gateway or approval implementation starts. Re-check whether they've been resolved in the docs before re-reporting — do not assume they're still open.
