# Model & Agent Runtime

The architecture separates two responsibilities: the **Agent Runtime** executes individual agents; the **Fleet Management layer** controls how the overall fleet operates. That separation holds regardless of which runtime sits underneath it — the section below is about what changed when the runtime changed.

## 7.1 OpenClaw Agent Runtime

> **Correction from the source spec — read this before anything else in this section.**
> The original reference architecture recommended the OpenAI Agents SDK as the agent runtime, and claimed it provides agents, tools, handoffs, guardrails, sessions, and runners as ready-made primitives. **This project uses OpenClaw instead**, and OpenClaw is not a drop-in replacement for that claim. OpenClaw is a self-hosted, model-agnostic automation runtime built around **skills** (WASM-sandboxed, manifest-driven, cryptographically verified on install), **event subscriptions**, and an **action loop**, with its own `plugin-sdk` — a different shape than an SDK purpose-built for manager/handoff multi-agent orchestration.
>
> The specific primitive list below (agents / tools / handoffs / guardrails / sessions / runners) describes what the OpenAI Agents SDK actually provides, not what's confirmed for OpenClaw. **Nothing in the Fleet Manager should be built assuming OpenClaw supplies these for free** until each one is checked against OpenClaw's actual API — route that through the `research` skill, not assumption. Treat every mention of "the runtime provides X" past this point as *inherited language from the source spec*, flagged, not as a verified fact about OpenClaw.

What doesn't change with the runtime swap: the Fleet Manager still owns the higher-level responsibilities, independent of what's underneath it.

```
AI FLEET PLATFORM
└── Fleet Manager
    ├── Agent Registry        → runtime-agents.md §3.3
    ├── Task Router            → orchestration.md §4.2
    ├── Workflow Manager       → workflow.md
    ├── Session Manager        → memory.md §6.2.2
    ├── Memory Manager         → memory.md
    ├── Permission Manager     → security-architecture.md
    ├── Usage Manager          → §7.4 below, observability.md
    ├── Observability          → observability.md
    └── Dashboard              → observability.md
         ↓
    OpenClaw Runtime   ← was "OpenAI Agents SDK" in the source spec — see correction above
         ↓
  ┌───────────┼───────────┐
  ↓            ↓            ↓
Research    Product    Engineering
 Agent       Agent        Agent
```

**Fleet layer** (runtime-agnostic — this doesn't change based on what executes underneath): which agents exist, where tasks route, how workflows are managed, how sessions and memory are managed, permissions, usage tracking, observability, dashboard.

**Runtime layer**: OpenClaw provides *some* set of primitives required to actually execute agents. What that set actually is — and where the Fleet Manager has to compensate by building something OpenClaw doesn't hand it for free (most likely candidate: structured agent-to-agent handoffs, given OpenClaw's event/skill model doesn't obviously map to that concept the way an SDK built around it would) — is an open implementation question, not a settled fact. This is the single highest-value thing for `research` and `architecture-review` to resolve early, since the rest of the Fleet Manager's design depends on knowing what it has to build versus what it gets for free.

## 7.2 Model Routing

Policy-driven selection of an appropriate LLM per task, based on complexity, latency, cost, and required accuracy. Don't use one expensive, high-capability model for every task regardless of what the task actually needs.

| Task type | Model tier |
|---|---|
| Simple classification | Lower-cost model |
| Research | Research/reasoning-capable model |
| Complex architecture | High-capability model |
| Code generation | Coding-capable model |
| Summarization | Efficient model |

```
Task
  ↓
Model Policy
  ↓
Evaluate Requirements
  ├── Complexity
  ├── Latency Requirement
  ├── Cost Budget
  └── Accuracy Requirement
  ↓
Selected Model
  ↓
Agent Execution
```

The point: never hard-code `EVERY TASK → SAME MODEL`. This is exactly the reasoning already applied to this project's own dev-loop agents — `architect`/`security` on the high-capability tier, `researcher`/`implementer`/`reviewer` on the cost-efficient tier — same policy, applied one level up to the runtime fleet itself.

## 7.3 Model Policy

Model selection weighs multiple factors together, not any single one in isolation:

```
                TASK
                  ↓
            MODEL POLICY
     ┌───────────┼───────────┐
 Complexity     Cost       Latency
     └───────────┼───────────┘
                  ↓
           Model Selection
```

A high-complexity task with a strict accuracy requirement can justify a more capable (and more expensive) model. A simple task with a tight cost or latency budget should use a more efficient one. This makes model selection a **platform policy**, not something each agent decides for itself — the same principle as deterministic task routing (`orchestration.md` §4.2): intelligence informs the decision, application logic enforces it.

## 7.4 Token Management

Every LLM call is tracked — who used the model, how many tokens, how long it took, how much it cost. Token usage is a first-class subsystem, not an afterthought bolted on for billing.

Every LLM call records:

| Field | | Field |
|---|---|---|
| Agent ID | | Cached Tokens |
| Task ID | | Estimated Cost |
| Session ID | | Latency |
| Model | | Timestamp |
| Provider | | |
| Input Tokens | | |
| Output Tokens | | |

```
                Token Usage
                    │
     ┌──────────────┼──────────────┐
   Agent           Task         Workflow
     │               │               │
   Cost            Cost            Cost
```

The platform calculates: cost per task, per agent, per department, per model, per user, per workflow, and daily/weekly/monthly cost. This matters more, not less, as the fleet grows — a cost leak that's negligible at low volume compounds fast at scale. Full detail on how this feeds the dashboard and alerting lives in `observability.md`.

## How Runtime, Model Routing, and Tokens Connect

```
TASK
  ↓
Executive Orchestrator
  ↓
Task Router
  ↓
Assigned Agent
  ↓
Model Policy
  ↓
Selected Model
  ↓
OpenClaw Agent Runtime   ← was "OpenAI Agent Runtime" — see §7.1 correction
  ↓
Agent Execution
  ↓
  ┌─────────────┴─────────────┐
Token Usage              Execution Data
  ↓                             ↓
Cost Tracking             Observability
```