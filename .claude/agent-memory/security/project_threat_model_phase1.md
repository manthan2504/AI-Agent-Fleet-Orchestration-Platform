---
name: threat-model-phase1
description: Working threat model for the Phase-1 fleet — who the plausible attacker is and which paths matter most, established during the 2026-08-18 docs audit.
metadata:
  type: project
---

Established 2026-08-18. Phase 1 is docs-only so far; this is the model to audit *against* as code lands.

Primary attacker is **not** a network intruder — it's whoever controls content the fleet ingests. Research and Product agents hold Web Search + Browser, so external web content is attacker-writable input that reaches agent context by design.

Ranked paths worth checking on every change:
1. **Indirect prompt injection → privileged agent.** Untrusted retrieved content lands in a shared store, a higher-privileged agent (Engineering: Git write, Filesystem, DB) reads it. See [[tool-permission-matrix-gaps]].
2. **Approval-gate bypass by misrepresentation.** The human approver sees agent-influenced free text, not the actual tool call. See [[approval-gate-design-gaps]].
3. **Principal confusion.** No documented split between agent-held and human-held API tokens, on an API surface that includes the approval endpoints.
4. **Cost/concurrency DoS.** `ApprovalRequest.timeout_ms` is optional; un-timed-out approvals hold tasks in `PENDING_APPROVAL` against per-department concurrency limits (orchestration.md §4.5) indefinitely.
5. **Cross-task context leakage** via shared organizational memory (memory.md §6.2.4) if retrieval isn't permission-aware per-call.

**Why:** the fleet's own architecture (specialized agents, shared knowledge, one gateway) makes confused-deputy chains the dominant risk class, not perimeter compromise.

**How to apply:** when auditing any new component, ask which of these five it touches before running a generic checklist.
