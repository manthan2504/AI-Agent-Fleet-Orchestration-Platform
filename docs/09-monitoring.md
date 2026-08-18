# Observability & Monitoring

An AI Agent Fleet runs many agents, tasks, tools, workflows, and model calls simultaneously. Knowing the system is "working" isn't enough — the platform needs to answer: what's happening, where, how long did it take, did something fail, and what caused it.

```
Observability
├── Logs
├── Distributed Tracing
├── Metrics
├── Event Bus
├── Agent Timeline
├── Live Execution View
└── Monitoring Dashboard
```

Seven complementary mechanisms, not seven independent ones — they're designed to be cross-referenced against each other during debugging (§10.7 covers exactly that path).

## 10.1 Logs

Every significant fleet event generates a structured, machine-readable log entry:

```json
{
  "timestamp": "...",
  "trace_id": "TRACE-92831",
  "task_id": "TASK-82931",
  "agent_id": "research-01",
  "event": "tool_call",
  "tool": "web_search",
  "status": "success",
  "latency_ms": 840
}
```

This is what lets an operator answer: which agent acted, on which task, calling which tool, did it succeed, how long did it take.

**Logs must not contain** sensitive prompt contents, credentials, tokens, or private information — this isn't a suggestion, it's the same rule already stated as a hard boundary in `security-architecture.md` §8.8 and in `.claude/rules/coding.md`. A log line is one of the easiest places for a secret to leak silently; treat it as sensitive-output-surface by default, not as a low-risk debugging convenience.

## 10.2 Distributed Tracing

Every request gets a unique **Trace ID**, which follows it through every component involved in executing it — logs tell you about individual events, tracing tells you how they connect across a complex, multi-component task.

```
TRACE-92831
├── Gateway
├── Security
├── Orchestrator
├── Router
├── Research Agent
├── Web Search
├── Knowledge Retrieval
└── LLM
```

If a result took too long, tracing localizes exactly where the delay actually happened:

```
Gateway → Agent → Web Search ← slow
```

A trace connects every operation belonging to one request or workflow into a single, followable execution path. This is what the `Trace ID` field in a task's metadata (`orchestration.md` §4.4.3) actually resolves to when you follow it.

## 10.3 Metrics

Numerical measurements collected across the fleet, agents, infrastructure, and LLMs — health, performance, usage, reliability, cost.

| Category | Tracks |
|---|---|
| **Fleet** | Active agents, idle agents, failed agents, tasks/second, queue depth |
| **Agent** | Tasks completed, task failures, average latency, token consumption, model usage, tool usage |
| **Infrastructure** | CPU, memory, disk, network, worker utilization |
| **LLM** | Input tokens, output tokens, cached tokens, latency, errors, retries, estimated cost |

These answer the questions that actually matter operationally: is the queue backing up, which department is overloaded, which agent is failing repeatedly, what are we spending on model usage. **This is the fulfillment of what `runtime.md` §7.4 (Token Management) and `orchestration.md`'s task-metadata cost/token fields point to** — those describe what gets recorded per call and per task; this is how it aggregates into something an operator actually reads. Fleet and Agent metrics also give the concrete numbers behind the health states already defined in `runtime-agents.md` §3.4 — "5 RUNNING, 2 IDLE, 1 ERROR" is the Fleet metric that section's state list rolls up into.

## 10.4 Event Bus

An internal event-distribution mechanism: when something important happens, the system publishes an event other components can consume without being directly coupled to agent execution.

```
Task starts → task.started event → Event Bus → Dashboard / Monitoring / Other Services
```

| Category | Events |
|---|---|
| Task | `task.created`, `task.assigned`, `task.started`, `task.completed`, `task.failed`, `task.retried` |
| Agent | `agent.started`, `agent.idle`, `agent.busy`, `agent.error`, `agent.stopped` |
| Tool | `tool.called`, `tool.completed`, `tool.failed` |
| Approval | `approval.requested`, `approval.approved`, `approval.rejected` |

```
Agent / Task System → Event Bus → Dashboard / Logs / Monitoring
```

The Task events map almost directly onto the task lifecycle states in `orchestration.md` §4.4.2 (`CREATED → QUEUED → ASSIGNED → RUNNING → COMPLETED/FAILED → RETRY`) — the event bus is what makes those state transitions observable to other components instead of only living inside the task queue's internal state. The Approval events are the observable side of `security-architecture.md` §8.7 and `workflow.md` §5.8 — every human-approval gate this platform enforces should be showing up here, auditable, not just executing silently.

## 10.5 Agent Timeline

Every task gets a chronological execution timeline — every important event that happened, in order:

```
09:32:01  Task created
09:32:02  Security check passed
09:32:03  Task classified as RESEARCH
09:32:03  Assigned to research-01
09:32:05  Session created
09:32:06  Memory retrieved
09:32:10  Web search started
09:33:02  Web search completed
09:34:21  LLM reasoning completed
09:35:11  Report generated
09:35:12  Task completed
```

This gives an operator a direct answer to "what happened to this task?" — particularly valuable for debugging slow or failed tasks, where the timeline itself is often most of the diagnosis. Note the "Memory retrieved" step: that's `memory.md` §6.3's retrieval flow, made visible as a concrete timestamped event rather than an invisible internal step.

## 10.6 Live Execution View

A real-time workflow graph — where a request currently is, not just a status string.

```
User
 │
Executive Orchestrator
 │
Task Router
 │
Research Agent
 ├── Web Search
 ├── Knowledge Retrieval
 └── Analysis
 │
Report
 │
Executive Orchestrator
 │
User
```

Different from a flat task list. Instead of `TASK-82931 → RUNNING`, an operator sees exactly where inside the workflow it is:

```
Research Agent
 ├── Web Search        ✓
 ├── Knowledge Retrieval ✓
 └── Analysis          ● RUNNING
```

## 10.7 Monitoring Dashboard

The centralized operational interface for the fleet — real-time visibility into agent status, task execution, token usage, cost, latency, and errors, at a glance.

**High-level view:**

| | | |
|---|---|---|
| Total Agents | Tasks Running | Tokens Used |
| Active Agents | Tasks Queued | Current Cost |
| Idle Agents | Tasks Completed | Daily Cost |
| | Tasks Failed | Average Latency / Error Rate |

**Dedicated views:** Overview, Agents, Tasks, Workflows, Sessions, Memory, Logs, Traces, Usage, Cost, Errors, Security, Approvals.

The dashboard is the central operational interface, and its real value is the drill-down path from high-level health to root cause:

```
Fleet Overview → Specific Agent → Specific Task → Task Timeline (§10.5) → Trace (§10.2) → Individual Event / Tool Call (§10.1)
```

That path — overview to individual log line, without switching tools — is the actual design target for this whole document. Every mechanism above (logs, traces, metrics, events, timeline, live view) exists to be a stop along that one path, not a standalone feature.

### Dashboard Build Scope

The dashboard is a real build target, not just a description of views. What it needs to actually ship, and where each piece is already specified elsewhere in this project's `docs/` so building the dashboard doesn't mean re-deciding any of it:

- [ ] **Agent status** — `runtime-agents.md` §3.3 (registry) and §3.4 (health states)
- [ ] **Live task view** — `orchestration.md` §4.4.2 (task lifecycle states)
- [ ] **Workflow graph** — `workflow.md` (sequential/parallel/branching structure) and §10.6 above (Live Execution View)
- [ ] **Logs** — §10.1 above
- [ ] **Traces** — §10.2 above
- [ ] **Metrics** — §10.3 above (Fleet / Agent / Infrastructure / LLM categories)
- [ ] **Token usage** — `runtime.md` §7.4
- [ ] **Cost** — `runtime.md` §7.4, aggregated per §10.3
- [ ] **Errors** — surfaced via Fleet/Agent metrics (§10.3) and the Agent Timeline (§10.5)
- [ ] **Approvals** — `security-architecture.md` §8.7, `workflow.md` §5.8
- [ ] **Memory explorer** — `memory.md` §6.2 (all five layers) and §6.3 (retrieval), backed by the vector DB store defined in `persistence.md` §9.3

> **Note:** this checklist corresponds to Phase 6 of the source spec's implementation roadmap (Foundation → Memory → Security → Task Infrastructure → Observability → **Fleet Dashboard** → Scale). That roadmap isn't documented anywhere in `docs/` yet — every phase reference so far (like `runtime-agents.md`'s "Current Phase Scope") has been informal. Worth building `docs/roadmap.md` at some point so "Phase 6" stops being a dangling reference and the dashboard's dependencies (it needs Task Infrastructure and Observability substantially built first) are explicit rather than assumed.