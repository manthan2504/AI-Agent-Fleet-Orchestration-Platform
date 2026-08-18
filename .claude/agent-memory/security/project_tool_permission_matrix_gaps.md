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

## Re-check 2026-08-18 (commit e432107) — status update

**Closed:** Filesystem split into read/write (QA and Security genuinely demoted to read-only — a substantive change, not just a column rename); `Database (read)` now `✓ (scoped¹)` via `Permission.resource_scope`; the Security row/rationale contradiction resolved with a stated narrow write exception; chained escalation added as an explicit named gap (honestly labelled unresolved, deferred to a workflow-level provenance control); default-`DENY` on policy-miss now stated; matrix stated as the compile source for `ToolPolicy`, with `Agent.Tools` validated against it and registration failing closed.

**NEW HIGH introduced by the fix — the precedence rule has no approval floor.** §8.3.2 now says most-specific-wins and that "a tool-specific `ALLOW` legitimately overrides a role-wide `REQUIRE_APPROVAL`", unconditionally. §8.3.1 says `⚠` "requires the Human Approval gate every time, regardless of role". Those contradict, and §8.3.2 is the one an implementer codes. Compounded: matrix *columns* are tool categories ("Cloud/Infra deploy"), `ToolPolicy.tool_id` is a concrete tool — the category→tool_id compilation is unspecified, so every `⚠` cell necessarily compiles to a *less* specific row than a hand-written `(role, concrete_tool_id, ALLOW)`, which then wins on specificity with no same-specificity write-time conflict to catch it.

**Fix shape:** state an irreducible floor — no `ToolPolicy` row at any specificity may resolve below `REQUIRE_APPROVAL` for the six §8.7 action classes; reject such a row at write time. This is the security-relevant carve-out the specificity rule is missing, not a replacement for it.

## Re-check 2026-08-18 (commit 0d5de5b) — the High is CLOSED

The floor landed as specified: §8.3.2 now names the six §8.7 action classes as an irreducible `REQUIRE_APPROVAL` floor no row at any specificity may resolve below, with write-time rejection, plus category-scoped compilation (a "Cloud/Infra deploy" cell compiles to a row per member `tool_id`, so a member tool can't out-specify its own category). That genuinely closes the specificity race — it doesn't just relocate it. `Filesystem (write)` → in-process-fallback precondition also closed, and closed hard ("no boundary at all", independent Gateway mandatory for that role).

**Residual, Medium — the floor's classification predicate.** The floor is only as good as the answer to "is this `tool_id` in one of the six classes?", and that predicate has two holes: (1) the matrix has columns for only 2 of the 6 classes (`Database (write)`, `Cloud/Infra deploy`) — credential rotation, financial transaction, external communication have no column, and "infrastructure destruction" isn't "deploy", so write-time rejection has nothing to evaluate for them; (2) the tool→category mapping has no stated provenance, while `risk_level` and now `designated_approver` both got an explicit "never agent-supplied" pin — the field the whole floor rests on didn't. Misclassifying a deploy tool under a `✓` category (e.g. `Filesystem (write)`, which Engineering holds) routes around the floor without violating any stated rule.

Rated Medium not High per [[docs-audit-severity-calibration]]: default-`DENY` plus fail-closed `Agent.Tools` registration cover the Phase-1 reachable paths, so a bypass needs an *additional* undocumented choice. **Upgrade to High if either** hand-authored `ToolPolicy` rows are confirmed a supported path, or tool→category classification turns out to be agent- or self-service-writable.

**Also open (pre-existing):** `tool_id`-omitted role-wide rows remain expressible while the matrix is claimed as the sole compile source — unclear whether hand-authored rows exist at all, and that ambiguity is what makes the floor gap reachable. And `Filesystem (write)` (Engineering) is now explicitly acknowledged as equivalent to code execution via Git hooks, which fully defeats — not merely "weakens" — the in-process `before_tool_call` gateway fallback the same section allows; the two additions aren't connected to each other.
