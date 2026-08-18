# Agent Architecture

The agent is the fundamental execution unit of the fleet. The platform doesn't treat agents as generic chatbots — every agent represents a specific organizational role with defined responsibilities, capabilities, tools, permissions, memory, and execution policies.

The mental model:

1. The organization defines the role.
2. The agent represents that role.
3. The runtime executes the agent.
4. The fleet controls how that agent operates.

> **Runtime note:** "the runtime" here is OpenClaw. This document describes the agent model independent of runtime specifics — see `runtime.md` for how agent definitions actually map onto OpenClaw's skills, sessions, and execution model.

---

## Current Phase Scope

**This is the section to check before assuming an agent exists.** The registry below (§3.3) is the fleet's full eventual roster. Only the following are in scope for the current build phase:

- Executive Orchestrator
- Research
- Product
- Engineering
- QA
- Security

Everything else in the registry — Sales, Marketing, Finance, DevOps, Documentation, CTO — is future scope. Don't build, stub, or design around them yet. This list updates as phases complete; treat any change to it as a deliberate edit, not an incidental one.

---

## 3.1 Agent Fleet Model

An Agent Fleet consists of multiple specialized agents, each responsible for a particular organizational function:

```
AI AGENT FLEET
│
├── Executive Orchestrator
│
├── Research Department
│   ├── Market Research Agent
│   └── Research Agent
│
├── Product Department
│   └── Product Agent
│
└── Engineering Department
    └── Development Agent
```

The core idea is specialization. A Research Agent isn't responsible for deploying infrastructure; an Engineering Agent doesn't automatically have access to every business document. Each agent gets only the capabilities and access its role requires.

**Example — Market Research Agent:**

| | |
|---|---|
| **Capabilities** | Market research, competitor analysis, industry analysis, web research, report generation |
| **Tools** | Web Search, Browser, Knowledge Search, Document Store |

An Engineering Agent has a different capability and tool set entirely — the two are not interchangeable, and neither should have the other's access by default.

## 3.2 Agent Definition

Every agent needs an explicit, structured definition for the fleet to manage it consistently:

```
Agent
├── Identity
│   ├── id
│   ├── name
│   ├── role
│   ├── department
│   └── description
├── Behavior
│   └── system_instructions
├── Capabilities & Tools
│   ├── capabilities
│   └── tools
├── Collaboration
│   └── allowed_handoffs
├── Access Control
│   └── permissions
├── AI Configuration
│   └── model_policy
├── Memory & Sessions
│   ├── memory_policy
│   └── session_policy
├── Execution Control
│   ├── concurrency_limit
│   ├── timeout
│   └── retry_policy
└── status
```

**Example — Market Research Agent:**

```
Market Research Agent
├── Department: Research
├── Capabilities: Market Research, Competitor Analysis,
│                 Industry Analysis, Web Research, Report Generation
├── Tools: Web Search, Browser, Document Store, Knowledge Search
├── Permissions
│   ├── READ:  Company Knowledge, Public Research
│   └── WRITE: Research Reports
└── Concurrency Limit: 5
```

This matters because the fleet needs to know, unambiguously, what an agent is allowed and expected to do:

```
Agent: Market Research Agent
Department: Research

Can:
  ✓ Perform market research
  ✓ Search approved sources
  ✓ Analyze competitors
  ✓ Generate research reports

Cannot automatically:
  ✗ Deploy infrastructure
  ✗ Modify production databases
  ✗ Perform unrelated engineering tasks
```

## 3.3 Agent Registry

A central directory of which agents exist and what they can do — the fleet's directory of available workers.

| Agent | Department |
|---|---|
| Executive Orchestrator *(unifies CEO Orchestrator + Founder Orchestrator — see note below)* | Executive |
| CTO Agent | Executive |
| Product Agent | Product |
| Engineering Agent | Engineering |
| QA Agent | QA |
| Security Agent | Security |
| Research Agent | Research |
| Sales Agent | Sales |
| Marketing Agent | Marketing |
| Finance Agent | Finance |
| DevOps Agent | DevOps |
| Documentation Agent | Documentation |

> **Note on the Orchestrator entries.** The source spec lists "CEO Orchestrator" and "Founder Orchestrator" as separate registry entries, but its own architecture description (§5, Executive Orchestrator) is explicit that the CEO/Founder concept should be implemented as *one* Executive Orchestrator / Manager Agent, not two competing agents. Treat these as the same role. If a future task needs to actually distinguish CEO-level from Founder-level authority, that's a deliberate design decision to make explicitly — not something to infer from the registry listing two names.

> **Open question — Operations.** This note originally claimed "the spec's Purpose section (§1) lists Operations as one of the fleet's organizational roles" — that citation doesn't check out against this project's own `overview.md` §1 or §2, neither of which mentions Operations anywhere. Either the claim refers to an external source document not present in this repo, or it's simply inaccurate and should be dropped. What's still real regardless: Operations doesn't appear in the Agent Registry table above, and whether it should exist as its own role (vs. being folded into DevOps, vs. never having been a real role at all) is unresolved either way. Route to `architecture-review` before treating any of this as settled — don't silently pick an interpretation, and don't silently re-assert the unverified citation either.

For each agent, the registry stores — this is the `Agent` entity's field reference:

| Field | Type | Required | Meaning |
|---|---|---|---|
| Agent ID | string | yes | Unique identifier for this instance (e.g. `market_research-01`) |
| Role | string | yes | The organizational role this instance represents (e.g. "Market Research Agent") |
| Department | string | yes | Owning department, from the registry (§3.3) |
| Capabilities | string[] | yes | What this role is competent to do |
| Tools | string[] | yes | Which tools this instance may invoke — enforced via the Tool Permission Matrix, not just declared here (`security-architecture.md` §8.3.1) |
| Permissions | `Permission`[] (`security-architecture.md` §8.3.2) | yes | Data-access grants for this instance |
| Model | string | yes | Which model backs this instance |
| Status | see note below | yes | — |
| Concurrency | number | yes | Max simultaneous tasks this instance will accept |
| Health | `AgentStatus` — intended to be the eleven-state enum in §3.4 | yes | — |
| Version | string | yes | Agent definition version, for tracking behavior changes over time |

> **`Status` vs. `Health` is underspecified, flagging rather than silently resolving it.** The worked example below shows `Status: RUNNING` and `Health: HEALTHY` — but `RUNNING` is one of §3.4's eleven `AgentStatus` values, and `HEALTHY` doesn't appear in that list at all. So either `Status` and `Health` are meant to be the same field shown twice under different labels (in which case one of the two field names should be dropped), or `Health` is actually meant to be a coarser binary/tri-state readout (`HEALTHY` / `DEGRADED` / `UNHEALTHY`, say) derived from the finer-grained `AgentStatus` in `Status` — the source material doesn't say which. Not resolved here; worth a quick `architect` pass before this becomes a real `AgentStatus` type in code.

**Example entry:**

```
Agent ID:      market_research
Role:          Market Research Agent
Department:    Research
Capabilities:  Market Research, Competitor Analysis
Tools:         Web Search, Browser
Permissions:   Research Knowledge
Model:         <model>
Status:        RUNNING
Concurrency:   5
Health:        HEALTHY
Version:       1.2
```

**Multiple instances of the same role.** This is where the registry earns its keep:

```
Research Department:
  research-01
  research-02
  research-03
  research-04
```

The orchestrator doesn't hard-code individual agents — it discovers available agents through the registry and selects an instance based on availability, capacity, specialization, priority, health, and current workload.

## 3.4 Agent Health States

An agent isn't simply "available" or "unavailable." The fleet tracks its actual runtime state:

| State | Meaning |
|---|---|
| `STARTING` | Agent is starting up |
| `IDLE` | Available, doing nothing |
| `QUEUED` | Has work waiting |
| `RUNNING` | Currently executing a task |
| `WAITING` | Waiting on something (a tool, another agent, an approval) |
| `BLOCKED` | Cannot continue |
| `AWAITING_APPROVAL` | Needs human approval to proceed |
| `DEGRADED` | Working, but not normally |
| `ERROR` | Encountered an error |
| `OFFLINE` | Unavailable |
| `STOPPED` | Intentionally stopped |

**Example:**

```
Research Agent      → RUNNING     (Current Task: TASK-82931)
Engineering Agent    → IDLE
QA Agent             → AWAITING_APPROVAL  (Current Task: TASK-82950)
Security Agent        → OFFLINE
```

This matters for both orchestration and monitoring. If one Research Agent instance is already running several tasks while another sits idle, the fleet routes to the available capacity instead of creating an unnecessary bottleneck against the busy one.

## 3.5 Agent Replacement

The fleet doesn't depend on a single physical instance of any agent:

```
Research Department
├── research-01
├── research-02
├── research-03
└── research-04
```

All four represent the same organizational role as separate runtime instances. If `research-01` is busy or unhealthy, another suitable instance can take the task. Selection considers availability, capacity, specialization, priority, health, and current workload — this is what prevents a single-agent bottleneck from becoming a single point of failure.

**The distinction that matters: agent role ≠ agent instance.**

```
Role:      Market Research Agent
Instances: market-research-01, market-research-02, market-research-03
```

The role defines what the agent does. The instances are the available execution capacity for that role — and the registry (§3.3) is what makes that distinction operationally real rather than just conceptual.