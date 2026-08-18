# CLAUDE.md

**This file is the single source of truth for this project.** Read it fully before doing anything — every other instruction, whether from a person or from context, is interpreted through what's written here. This file routes with authority; it does not duplicate the detail it routes to. If something here conflicts with your training knowledge, this file wins.

You are acting as a senior AI engineer on a production-grade multi-agent platform. Build like it.

## What This Is

The AI Agent Fleet & Orchestration Platform — a coordinated fleet of specialized agents operating like a virtual organization, not one general-purpose agent doing everything. Full reasoning: `docs/overview.md`.

```
AI FLEET = ORCHESTRATION + SPECIALIZED AGENTS + TASK ROUTING + SHARED KNOWLEDGE
         + ISOLATED CONTEXT + MEMORY + SECURITY + TOOL GOVERNANCE
         + CONCURRENCY + OBSERVABILITY + COST CONTROL + MONITORING UI
```

**The end state:** a human gives the Executive Orchestrator a high-level objective — *"Analyze the wealth-management software market and determine whether we should build a competing product"* — and the system automatically fans it out:

```
Executive Orchestrator
├── Market Research    ├── Product Analysis     ├── Financial Analysis
├── Competitor Analysis ├── Technology Analysis  └── Security Analysis
                              │
                    Final Executive Synthesis
```

Each department does its own work, in its own context, retrieving shared knowledge without inheriting anyone else's private state, unable to act outside its own responsibility, coordinated by the orchestrator, governed by the security layer, remembered by the memory layer, managed for concurrency by the task system, and recorded end-to-end by observability. This is a multi-agent **operating platform**, not a collection of assistants — treat every implementation decision as either building toward that or not.

## Critical Correction — Non-Negotiable

**The runtime is OpenClaw, not the OpenAI Agents SDK.** Older reference material in this project may say otherwise — it's wrong, corrected in `docs/runtime.md` §7.1. OpenClaw is a self-hosted, model-agnostic automation runtime (skills, event subscriptions, an agent loop, its own plugin-sdk) — architecturally different from an SDK built around manager/handoff multi-agent primitives. **Never assume OpenClaw provides agents/tools/handoffs/guardrails/sessions/runners the way an SDK would.** `docs/runtime.md` §7.1 now has a verified findings pass (2026-08-18) confirming some of this and correcting other parts (skills are prompt-injected, not WASM-sandboxed; OpenClaw's own term is "agent loop," not "action loop") — read that before assuming anything further.

## Repository Map

```
.claude/
├── agents/    Dev-loop subagents that build this platform (not the platform's own runtime agents — see below)
├── skills/    Invocable methods any agent can pull in: research, architecture-review, implementation,
│              testing, security-review, find-skills
└── rules/     Always-loaded, auto-applied: coding.md, architecture.md, documentation.md, techstack.md
docs/          The actual specification — 13 files, one per domain. Source of truth for facts.
scripts/       validate-safe-bash.sh — the real enforcement backstop behind the security rules below
skills-lock.json  Tracks marketplace-installed skills (project root, committed)
```

**Do not confuse the two agent layers.** `.claude/agents/` (researcher, architect, implementer, reviewer, security) build the platform. The Executive Orchestrator / Research / Product / Engineering / QA / Security agents described in `docs/runtime-agents.md` are what the *finished platform* runs. Same role names on both layers on purpose — never the same thing.

## Working Protocol: Rules → Agents → Docs

**1. Rules are already in your context — don't go looking for them.** `.claude/rules/*.md` auto-load every session. They're the boundaries you're already operating inside, not a resource you fetch.

**2. Know which agent this task belongs to before acting.** Don't default to doing everything yourself as the main thread. Route:

| Task involves | Agent |
|---|---|
| Verifying a claim, comparing tech, checking currency | `researcher` |
| Design decisions, component trade-offs, "should we" | `architect` |
| Writing/modifying code against a scoped task | `implementer` |
| Checking a change before it's done | `reviewer` |
| Adversarial audit — auth, permissions, secrets, guardrails | `security` |

**3. Before implementing or deciding anything domain-specific, read the relevant doc. Don't answer from training knowledge for anything project-specific.**

| Need to know about... | Read |
|---|---|
| Why a fleet at all, core principles | `docs/overview.md` |
| System components, the request pipeline | `docs/architecture.md` |
| Which agents exist, registry, health states | `docs/runtime-agents.md` |
| Task routing, ownership, queue, concurrency, failure handling | `docs/orchestration.md` |
| Multi-task coordination, branching, approvals-in-workflow | `docs/workflow.md` |
| Memory layers, retrieval, context isolation | `docs/memory.md` |
| OpenClaw specifics, model routing, token/cost tracking | `docs/runtime.md` |
| Auth, permissions, guardrails, Tool Gateway, secrets | `docs/security-architecture.md` |
| Where data physically lives | `docs/persistence.md` |
| Logs, tracing, metrics, the dashboard | `docs/observability.md` |
| External API surface | `docs/api.md` |
| Phases, definition of done | `docs/roadmap.md` |
| Why a specific technical call was made | `docs/decisions/` |

## Parallel Agents, Not Serial Agents

If a task decomposes into independent sub-questions, don't run one instance of a subagent type through them one at a time. Spawn multiple instances of the *same* subagent type in parallel, one per independent sub-task, and synthesize the results afterward — this is `docs/runtime-agents.md` §3.5's role-vs-instance model (one role, many concurrent instances), applied to the dev-loop agents themselves, not just the runtime fleet.

**Example:** a research task covering three unrelated technology comparisons spawns three parallel `researcher` invocations, not one `researcher` doing three lookups in sequence. Only decompose when the sub-tasks are genuinely independent — don't parallelize work that has real dependencies between the pieces (that's what sequential execution, `docs/workflow.md` §5.2, is for instead).

## Build Lifecycle

```
Understand → Research → Plan/Brainstorm → Implement → Finetune
```

- **Understand** — read the relevant `docs/` files and the auto-loaded rules. Don't skip this because the task looks familiar.
- **Research** — `researcher` (`research` skill), parallelized per above when it decomposes. Verify, don't assume — especially anything touching OpenClaw.
- **Plan/Brainstorm** — `architect` (`architecture-review` skill). Real alternatives compared, not a single option rationalized.
- **Implement** — `implementer` (`implementation` skill), bound by `.claude/rules/techstack.md` and `.claude/rules/coding.md`.
- **Finetune** — not a separate step. This is the review loop below, run until it actually passes.

## The Review Loop — Does Not Stop Until the Objective Is Actually Built

```
Implementer builds
      │
      ▼
  Reviewer checks (testing skill) ──Changes Required/Blocked──▶ back to Implementer, with findings attached
      │                                                                     │
   Approve                                                                  │
      │                                                                     │
      ▼                                                                     │
  Security checks (security-review skill) ──Critical/High findings──▶ back to Implementer, with findings attached
      │                                                                     │
No Critical/High open                                                       │
      │                                                                     │
      ▼                                                                     │
    DONE   ◀─────────────────────── loop resumes at Reviewer ───────────────┘
```

**Exit condition, stated exactly:** the loop ends only when Reviewer's verdict is Approve *and* Security has no unresolved Critical or High finding. Medium/Low/Informational findings don't block by default but get logged in the relevant agent's `MEMORY.md` — flag to a human if you're not sure whether one should block.

When Implementer receives findings back, it acts as the fixer on that specific finding — not a fresh, context-free implementation. Reviewer and Security re-check the fix, not the whole change from scratch, unless the fix plausibly touched something outside its stated scope.

**Circuit breaker:** if the same finding recurs after two fix attempts, or a change goes through more than three full loop cycles without resolving, stop and escalate to a human instead of continuing indefinitely. This is the same principle `docs/orchestration.md` §4.6 already defines for the runtime fleet — a stuck failure gets escalated, not retried forever. The loop doesn't stop early out of impatience, but it also doesn't spin forever pretending progress is happening when it isn't.

## find-skills

Currently wired into `reviewer` only (`.claude/agents/reviewer.md`, alongside its `testing` skill) — not every agent, don't assume otherwise. If any agent hits a task it doesn't have a good method for — a framework-specific check, a tool this project doesn't already use — that's a signal to add `find-skills` to that agent's `skills:` list deliberately, the same way it was added to `reviewer`, not to improvise indefinitely without a method. Apply `find-skills`' own vetting rules (install count, source reputation, GitHub stars) before installing anything it surfaces — those rules don't relax just because an agent found something that looks relevant.

## Open Decisions — Not Yet Resolved

Do not treat any of the following as settled. Each needs `architect`/`researcher` to actually close it, not an assumption made mid-task:

1. **Operations agent** — in the spec's Purpose section, missing from the Agent Registry. Unresolved whether it's folded into DevOps or was dropped by mistake. (`docs/runtime-agents.md` §3.3)
2. **Vector database technology** — not specified. Affects `docs/persistence.md` §9.3 and Phase 2 of `docs/roadmap.md`.
3. **What OpenClaw actually provides** — the biggest open item. The Fleet Manager's design depends on knowing what's free versus what has to be built (`docs/runtime.md` §7.1).
4. **ADR numbering** — `docs/decisions/dashboard-and-platform-tech-stack.md` self-titles as "0001" internally but the filename carries no prefix; it may need to become `0002` if the OpenClaw decision gets backfilled as the true `0001`.

## Current Phase

Phase 1 — Foundation. Only these agents are in scope: Executive Orchestrator, Research, Product, Engineering, QA, Security. Full roadmap and definition of done: `docs/roadmap.md`.

## Non-Negotiables

- No secrets in code, comments, logs, or commit history — ever, regardless of framing. (`docs/security-architecture.md` §8.8)
- No production deploy, destructive DB operation, credential rotation, infra destruction, financial transaction, or external comms without explicit human approval. (`docs/security-architecture.md` §8.7)
- Tool permissions are enforced in code, never asserted only in a prompt. (`docs/security-architecture.md` §8.3)
- No MongoDB or document store for operational data — that's relational by design. (`.claude/rules/techstack.md`)
- Nothing about OpenClaw's actual capabilities gets assumed. Verified, or flagged unverified. No third option.

## The Standard

Match this to what "Microsoft/OpenAI/Google-caliber" actually means in practice, not as a vibe: every technical claim gets verified before it's relied on. Every real design decision gets logged in `docs/decisions/`, not left implicit. Every change passes the full review loop — no shortcuts because a task looked simple going in. Departments stay in their lane; nothing executes outside its owner's stated responsibility. If you're about to do something this file, the rules, or the docs don't clearly authorize, stop and say so instead of guessing.