---
name: openclaw-primitives
description: Verified facts about what OpenClaw (the project's actual agent runtime) provides vs. doesn't — skills, hooks, agent loop, plugin-sdk, sub-agent handoffs, sessions, task queue.
metadata:
  type: project
---

Verified 2026-08-18 against docs.openclaw.ai (official docs) and github.com/openclaw/openclaw (official repo). Full detail and inline citations written directly into `docs/runtime.md` §7.1 ("Verified findings" subsection) — that's the canonical record; this memory is an index/pointer plus the headline corrections.

**Why this mattered:** `docs/runtime.md` §7.1 had inherited-but-unverified claims about OpenClaw (skills "WASM-sandboxed... cryptographically verified on install"; predicted the biggest gap vs. the OpenAI Agents SDK was "structured agent-to-agent handoffs"). CLAUDE.md and `.claude/rules/architecture.md` both flag this as the single highest-value open item — the Fleet Manager's design depends on knowing what OpenClaw gives for free.

**Headline corrections (all with sources in docs/runtime.md):**
- Skills are NOT WASM-sandboxed — they're prompt-injected `SKILL.md` instruction packs (YAML frontmatter + markdown), not an isolated execution runtime.
- Skills are NOT cryptographically verified on install by default. `openclaw skills verify` checks a ClawHub "trust envelope" (registry/security-scan metadata), not a signature/hash of the content. Docs themselves say "treat third-party skills as untrusted code"; independent security research (arXiv:2606.01494, arXiv:2603.27517) corroborates no signature/hash check and full host-agent privileges by default.
- Real sandboxing exists but is separate from skills: opt-in, off-by-default, container-based (Docker/Podman/SSH/OpenShell) tool-execution isolation, not WASM.
- "Event subscriptions" = Hooks (real, confirmed): scripts triggered on named Gateway events (command/session/agent/gateway/message lifecycle events).
- "Action loop" — OpenClaw's own term is **agent loop** (terminology only), and it's a single-session serialized loop (intake→context→inference→tools→stream→persist), not a multi-agent orchestration construct.
- Multi-agent: OpenClaw DOES have solid per-agent SQLite-backed session/state isolation, and a `sessions_spawn`/`sessions_yield`/"announce" async delegation pattern that's a real (if in-process, non-durable) handoff primitive — better than the doc's prior prediction assumed. What's genuinely missing: task/domain-based routing (OpenClaw's own "multi-agent routing" is channel-binding, i.e. which persona owns a conversation, not which department owns a task) and any durable/cross-process task queue (persistence, priority, retry, dead-letter) — this second point is unverified-as-absent, not confirmed-absent.

**Still open, not resolved by this pass:** whether `plugin-sdk`'s `trustedToolPolicies` is sufficient for the project's full Permission Manager (Security's call). Whether a durable task queue exists anywhere in OpenClaw beyond the in-process sub-agent pattern. NeMo Guardrails hook-point integration (separate question, untouched here).

**Confidence:** High on the verified corrections (primary source docs.openclaw.ai + repo, cross-checked against independent security literature for the skills-verification claim). Medium on "no durable task queue" (absence in docs isn't proof of absence — flagged as such, not asserted as fact).

**Re-check condition:** OpenClaw is fast-moving (personal-automation runtime space). Re-verify before Phase 2 architecture work locks in Task Router / durable queue design, and if this memory is more than ~2-3 months old relative to when it's read.
