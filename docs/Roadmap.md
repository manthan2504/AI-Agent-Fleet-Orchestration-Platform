# Implementation Phases

This is the canonical phase roadmap for the project — every informal phase reference elsewhere in `docs/` (`runtime-agents.md`'s "Current Phase Scope", `observability.md`'s Dashboard Build Scope) points back to this file. Phases are staged for a single-VM deployment first (`architecture.md` §2.1); Phase 7 is explicitly what comes after that's stable, not a parallel track.

**Current status:** Phase 1, in progress. See `runtime-agents.md` for exactly which agents are in scope right now.

## Phase 1 — Foundation

Build:

- [ ] VM environment
- [ ] OpenClaw runtime *(source spec said "OpenAI Agents SDK" — see `runtime.md` §7.1 for the correction and the still-open question of what OpenClaw actually provides)*
- [ ] Basic agent registry — `runtime-agents.md` §3.3
- [ ] Executive Orchestrator — `orchestration.md` §4.1
- [ ] Task router — `orchestration.md` §4.2
- [ ] Task database — `persistence.md` §9.2
- [ ] Basic session management — `memory.md` §6.2.2
- [ ] Basic logging — `observability.md` §10.1

**Initial agents** (also the authoritative source for `runtime-agents.md`'s current-phase scope line): Executive Orchestrator, Research, Product, Engineering, QA, Security.

## Phase 2 — Memory

Implement:

- [ ] Session memory — `memory.md` §6.2.2
- [ ] Working memory — `memory.md` §6.2.1
- [ ] Organizational knowledge — `memory.md` §6.2.4
- [ ] Vector retrieval — `memory.md` §6.3, `persistence.md` §9.3 *(depends on the still-open vector DB technology decision)*
- [ ] Memory permissions — `security-architecture.md` §8.4
- [ ] Context filtering — `memory.md` §6.5
- [ ] Summarization / compaction — `memory.md` §6.5

## Phase 3 — Security

Integrate:

- [ ] NVIDIA NeMo Guardrails — `security-architecture.md` §8.5
- [ ] Authentication — `security-architecture.md` §8.2
- [ ] Authorization — `security-architecture.md` §8.2
- [ ] Tool permissions — `security-architecture.md` §8.3
- [ ] Execution policies — `security-architecture.md` §8.5 (execution rails)
- [ ] Output policies — `security-architecture.md` §8.5 (output rails)
- [ ] Secret management — `security-architecture.md` §8.8
- [ ] Audit logs — `observability.md` §10.1

## Phase 4 — Task Infrastructure

Implement:

- [ ] Durable task queue — `orchestration.md` §4.4.1
- [ ] Worker architecture — `orchestration.md` §4.5
- [ ] Concurrency — `orchestration.md` §4.5
- [ ] Retries — `workflow.md` §5.6, `orchestration.md` §4.6
- [ ] Timeouts — `workflow.md` §5.6
- [ ] Priority queues — `orchestration.md` §4.4.3 (Priority field)
- [ ] Workflow dependencies — `workflow.md` §5.5
- [ ] Parallel execution — `workflow.md` §5.3

## Phase 5 — Observability

Implement:

- [ ] OpenTelemetry — proposed in the source spec as the common telemetry standard, on the basis that NeMo Guardrails' current documentation supports OpenTelemetry-based tracing (visibility into LLM calls and token usage). **Flagging, not asserting**: this is exactly the kind of claim that goes stale fast — verify via `research` before treating it as settled, same as every other specific tool-capability claim in this project.
- [ ] Structured logs — `observability.md` §10.1
- [ ] Distributed traces — `observability.md` §10.2
- [ ] Metrics — `observability.md` §10.3
- [ ] Token tracking — `runtime.md` §7.4
- [ ] Model tracking — `runtime.md` §7.4
- [ ] Cost tracking — `runtime.md` §7.4, `observability.md` §10.3
- [ ] Error tracking — `observability.md` §10.3, §10.5

## Phase 6 — Fleet Dashboard

Full build checklist already lives in `observability.md` §10.7 (Dashboard Build Scope) — not repeated here to avoid two copies drifting apart. Tech stack for this phase is decided: `docs/decisions/0001-dashboard-and-platform-tech-stack.md`, enforced via `.claude/rules/tech-stack.md`.

**Depends on:** Phase 4 and Phase 5 substantially built — the dashboard displays task state, traces, metrics, and costs that don't exist to display until those phases produce them. This is inference from what the dashboard actually needs, not stated explicitly in the source spec, but worth treating as a real dependency rather than starting dashboard work in parallel with infrastructure that isn't emitting anything yet.

## Phase 7 — Scale

Once the single-VM implementation is stable:

- [ ] Separate workers
- [ ] Horizontal scaling
- [ ] Multiple agent instances — `runtime-agents.md` §3.5 (Agent Replacement already establishes the role-vs-instance model this scales)
- [ ] Queue scaling — `orchestration.md` §4.4.1
- [ ] Distributed memory — `persistence.md`
- [ ] Load balancing
- [ ] High availability
- [ ] Worker autoscaling

No existing `docs/` file covers load balancing, HA, or autoscaling in any depth — this phase is the least specified of the seven. If a distributed-architecture section of the source spec exists beyond what's been pasted so far (the single-VM diagram in `architecture.md` §2.1 hints at one), that's worth sending before Phase 7 planning gets concrete.

## Initial Definition of Done

The acceptance checklist for a production-ready first version — this is what "Phases 1 through 6 are actually done" means concretely, not a restatement of the phases themselves. Every item below cross-references where it's already specified; nothing here is new architecture, only new verification criteria.

**Agent Fleet** *(Phase 1)*
- [ ] Agent registry exists — `runtime-agents.md` §3.3
- [ ] Agents have explicit roles — `runtime-agents.md` §3.2
- [ ] Agents have explicit capabilities — `runtime-agents.md` §3.2
- [ ] Agents have explicit permissions — `runtime-agents.md` §3.2, `security-architecture.md` §8.3
- [ ] Agents have health/status states — `runtime-agents.md` §3.4

**Orchestration** *(Phase 1, Phase 4)*
- [ ] Executive orchestrator exists — `orchestration.md` §4.1
- [ ] Task classification works — `orchestration.md` §4.2
- [ ] Deterministic routing exists — `orchestration.md` §4.2
- [ ] Tasks have owners — `orchestration.md` §4.3
- [ ] Complex tasks can be decomposed — `orchestration.md` §4.4.4
- [ ] Agent collaboration is controlled — `orchestration.md` §4.7

**Memory** *(Phase 2)*
- [ ] Working memory exists — `memory.md` §6.2.1
- [ ] Session memory exists — `memory.md` §6.2.2
- [ ] Agent memory exists — `memory.md` §6.2.3
- [ ] Organizational memory exists — `memory.md` §6.2.4
- [ ] Retrieval is permission-aware — `memory.md` §6.3
- [ ] Full context is not blindly injected — `memory.md` §6.1, §6.5

**Execution** *(Phase 4)*
- [ ] Tasks are queued — `orchestration.md` §4.4.1
- [ ] Tasks execute asynchronously — `orchestration.md` §4.5
- [ ] Multiple agents can work concurrently — `orchestration.md` §4.5
- [ ] Retry logic exists — `orchestration.md` §4.6, `workflow.md` §5.6
- [ ] Timeout handling exists — `workflow.md` §5.6
- [ ] Failed tasks can be recovered — `orchestration.md` §4.6

**Security** *(Phase 3)*
- [ ] Authentication exists — `security-architecture.md` §8.2
- [ ] Authorization exists — `security-architecture.md` §8.2
- [ ] Tool permissions exist — `security-architecture.md` §8.3
- [ ] NeMo Guardrails is integrated — `security-architecture.md` §8.5
- [ ] High-risk operations can require approval — `security-architecture.md` §8.7
- [ ] Secrets are isolated — `security-architecture.md` §8.8

**Cost** *(Phase 5)*
- [ ] Token usage is tracked — `runtime.md` §7.4
- [ ] Model usage is tracked — `runtime.md` §7.4
- [ ] Cost is calculated — `runtime.md` §7.4
- [ ] Per-agent usage is available — `runtime.md` §7.4, `observability.md` §10.3
- [ ] Per-task usage is available — `runtime.md` §7.4, `orchestration.md` §4.4.3
- [ ] Context optimization exists — `memory.md` §6.5

**Observability** *(Phase 5)*
- [ ] Structured logs exist — `observability.md` §10.1
- [ ] Metrics exist — `observability.md` §10.3
- [ ] Distributed tracing exists — `observability.md` §10.2
- [ ] Every task has a trace ID — `orchestration.md` §4.4.3, `observability.md` §10.2
- [ ] Tool calls are observable — `observability.md` §10.1, §10.4
- [ ] Errors are observable — `observability.md` §10.3, §10.5

**UI** *(Phase 6)*
- [ ] Agent status dashboard exists — `observability.md` §10.7
- [ ] Task dashboard exists — `observability.md` §10.7
- [ ] Live execution view exists — `observability.md` §10.6
- [ ] Logs are searchable — `observability.md` §10.1, §10.7
- [ ] Traces are viewable — `observability.md` §10.2, §10.7
- [ ] Token usage is visible — `observability.md` §10.7, `runtime.md` §7.4
- [ ] Cost is visible — `observability.md` §10.7
- [ ] Errors are visible — `observability.md` §10.7
- [ ] Approvals are visible — `observability.md` §10.7, `security-architecture.md` §8.7

Notably absent from this checklist: nothing here checks for the three open decisions this project has flagged (Operations-agent discrepancy, vector DB technology, what OpenClaw actually provides for handoffs/sessions). A "production-ready v1" that satisfies every box above could still be built on an unresolved assumption in any of those three — this checklist verifies breadth of implementation, not that every underlying design question has actually been closed. Worth treating those as a separate, mandatory gate before calling v1 done, not something this checklist happens to catch.