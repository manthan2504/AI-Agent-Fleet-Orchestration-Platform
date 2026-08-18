# API & Platform Interface

The entry point through which users, the dashboard, and other systems interact with the fleet. External clients don't talk to individual agents directly — they talk to the Fleet Platform through defined APIs.

```
User / Dashboard / External System
              │
          Fleet API
              │
   ┌──────────┼──────────┐
 Tasks       Agents    Workflows
   └──────────┼──────────┘
              │
        Fleet Platform
```

The API layer provides one consistent way to create tasks, inspect execution, monitor agents, retrieve results, and manage approvals — everything documented elsewhere in `docs/` from the internal side, exposed here from the outside.

## 11.1 API Design

Clear, resource-oriented endpoints:

```
/tasks
/agents
/sessions
/workflows
/usage
/costs
/approvals
/health
```

A client interacts with the fleet without needing to understand any component's internal implementation. `POST /tasks` is the whole interface a client needs — not direct calls into the Task Router, Agent Runtime, Memory Service, or a specific agent. The platform owns everything behind that single call.

## 11.2 Task APIs

Create and inspect submitted work.

```
POST /tasks
GET  /tasks/{id}
GET  /tasks/{id}/events
GET  /tasks/{id}/trace
```

A client can create a task, check its status, view its events, and inspect its execution trace. This is the external interface to the task lifecycle already defined in `orchestration.md` §4.4.2 — the API surfaces the same states, it doesn't define new ones:

```
POST /tasks → Created → Queued → Assigned → Running → Completed
```

## 11.3 Agent APIs

Inspect the agents making up the fleet.

```
GET /agents
GET /agents/{id}
```

Exposes the same fields defined in the Agent Registry (`runtime-agents.md` §3.3): ID, role, department, capabilities, tools, permissions, model, status, concurrency, health, version. `GET /agents/research-01` returns that agent's current state — letting the dashboard read off the health states already defined in `runtime-agents.md` §3.4 (`IDLE`, `RUNNING`, `WAITING`, `BLOCKED`, `DEGRADED`, `ERROR`, `OFFLINE`) rather than the API inventing its own status vocabulary.

## 11.4 Session APIs

The execution context tied to a conversation or workflow.

```
GET /sessions/{id}
```

Returns session ID, user request, agent interactions, tool calls, task state, intermediate outputs — same shape as `memory.md` §6.2.2's Session Memory layer. Authorized clients inspect the context for one specific execution without exposure to unrelated sessions, which is the API-level expression of context isolation (`memory.md` §6.4): each session has its own execution context, and this endpoint provides controlled access to exactly that one context, nothing adjacent to it.

## 11.5 Workflow APIs

Inspect larger multi-task, multi-agent execution structures.

```
GET /workflows/{id}
```

```
User Request
     │
Orchestrator
     ├── Research
     ├── Product
     ├── Engineering
     └── QA
          │
     Final Result
```

Exposes a workflow's current state, tasks, dependencies, agent assignments, execution progress, and results — the API-level view of everything `workflow.md` defines conceptually (sequential/parallel execution, dependencies, branching). This is what feeds the Live Execution View in the dashboard (`observability.md` §10.6).

## 11.6 Usage & Cost APIs

Token consumption and model usage, exposed for consumption without querying the underlying databases directly.

```
GET /usage
GET /costs
```

Tokens used, model usage, cost per task/agent/department/model, daily/monthly cost — the same fields `runtime.md` §7.4 defines as tracked and `observability.md` §10.3/§10.7 defines as aggregated. This endpoint is how that aggregation actually reaches a dashboard or an external reporting system.

```
GET /costs
    │
Fleet Cost
    ├── Research
    ├── Engineering
    ├── Product
    └── QA
```

## 11.7 Approval APIs

Managing human-approval requests for high-risk actions.

```
POST /approvals/{id}/approve
POST /approvals/{id}/reject
```

```
Agent → Tool Request → Risk Evaluation → Approval Created → Human → Approve/Reject → Workflow Continues/Stops
```

This is the API surface for the approval gate already defined in `security-architecture.md` §8.7 and `workflow.md` §5.8 — the mechanism doesn't change here, this just gives a dashboard or another authorized interface a concrete way to act on it.

## 11.8 Example Task API

**Request:**

```json
POST /tasks
{
  "task": "Research wealth management tools",
  "priority": "normal"
}
```

**Response:**

```json
{
  "task_id": "TASK-82931",
  "status": "queued",
  "department": "research",
  "assigned_agent": "market_research"
}
```

The client never needs to know how the task was routed internally. Behind this one API call, the platform runs the full path already documented across this project's `docs/`:

```
API → Security (security-architecture.md) → Classification → Deterministic Routing (orchestration.md §4.2)
    → Agent Assignment (runtime-agents.md §3.3) → Session (memory.md §6.2.2) → Memory Retrieval (memory.md §6.3)
    → Agent Execution (runtime.md) → Result
```

The client interacts with a simple, stable API surface. Everything above the line stays free to change internally — including, eventually, the still-open OpenClaw runtime question in `runtime.md` §7.1 — without breaking what a client actually calls.