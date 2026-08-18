---
name: tool-permission-matrix-gaps
description: Adversarial gaps in security-architecture.md §8.3.1's Tool Permission Matrix and §8.3.2's ToolPolicy entity — chained-privilege paths and unspecified policy-evaluation defaults, from the 2026-08-18 docs audit.
metadata:
  type: project
---

Audited 2026-08-18 against §8.3.1 (six Phase-1 agents) and §8.3.2.

**Chained escalation the per-cell matrix doesn't capture:**
- Research/Product have Web Search + Browser (untrusted external content) *and* Doc Store write. Engineering reads the Doc Store and holds Git write + Filesystem. Untrusted web content → research report → Engineering context → committed code. No single cell grants this; the chain does.
- `Filesystem` is one undifferentiated column (no read/write split, unlike Git). QA and Security both get `✓` Filesystem while being denied Git write. Filesystem write over a repo working tree, `.git/`, or a hook is effectively Git write plus code execution — it defeats the stated "QA reads and runs it without committing" intent.
- `Database (read)` is unscoped — the doc's own motivating example is "Research Agent → Production Database ✗", but three roles get an unqualified DB read. `Permission.resource_scope` exists but the matrix only uses that style of narrowing on Doc Store write.

**Internal contradiction:** the §8.3.1 rationale says Security gets "no write access anywhere" while the Security row shows Doc Store write `✓` and Filesystem `✓`.

**ToolPolicy evaluation is underspecified in ways that default unsafe:**
- `tool_id` optional ("omit to match all"), with no stated precedence, specificity ordering, or most-restrictive-wins rule — a role-wide `ALLOW` can shadow a tool-specific `REQUIRE_APPROVAL`.
- No stated behavior when *no* policy matches. Approval timeout is explicitly fail-closed; policy-miss is not.
- No stated mechanism compiling the matrix into enforced `ToolPolicy` rows, and no stated conflict behavior against `Agent.Tools` (runtime-agents.md §3.3), which is the field with a concrete type — the matrix risks becoming documentation rather than the control.

**How to apply:** raise these before the Permission Manager / Tool Gateway is designed, not after. When reviewing any future matrix edit, check chains across rows, not just cells.
