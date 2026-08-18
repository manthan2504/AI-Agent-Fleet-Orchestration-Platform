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

### 11.1.1 Contract Conventions

Fleet-wide conventions every endpoint below follows, so they don't need repeating per-endpoint:

**Auth.** Every request carries `Authorization: Bearer <token>`, validated at the Fleet Gateway before anything else runs (`security-architecture.md` §8.1's first two layers — Authentication then Authorization). Missing/invalid token → `401`. Valid token, insufficient authorization for the specific resource → `403`. This document fixes the header convention; the token/session issuance mechanism itself isn't specified yet — flag before implementing, don't assume a scheme.

**Pagination.** List-shaped responses (`GET /agents`, `GET /usage`, `GET /costs`) use cursor pagination: `?limit=<n>` (default 20, max 100) and `?cursor=<opaque>`. Response includes `next_cursor` (`null` when exhausted). Not offset-based — task/agent/event volume makes offset pagination drift under concurrent writes.

**Filtering.** List endpoints accept `?status=`, `?department=`, and `?created_after=`/`?created_before=` where the underlying resource has those fields (e.g. `GET /tasks` isn't listed as a bare endpoint above but if added, filters by `TaskStatus`, department, timestamps — same fields the entity already carries, `orchestration.md` §4.4.3).

**Idempotency.** `POST /tasks` and the approval endpoints (`POST /approvals/{id}/approve`/`reject`) accept an `Idempotency-Key` header. A replayed request with a previously-seen key returns the original response (same status code, same body) instead of creating a second task or double-resolving an approval — necessary because a client retrying a timed-out request must not accidentally submit the same task twice or approve-then-approve-again.

**Error shape.** Every non-2xx response returns the same envelope:

```json
{
  "error": {
    "code": "TASK_NOT_FOUND",
    "message": "No task found with id TASK-82931",
    "request_id": "req_9f2a..."
  }
}
```

`code` is a stable machine-readable string (for client branching); `message` is human-readable and not guaranteed stable across versions; `request_id` ties the response back to a trace (`observability.md` §10.2) for support/debugging.

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

**Status codes:** `POST /tasks` → `201` + the created task on success, `400` on a malformed request body, `401`/`403` per §11.1.1. `GET /tasks/{id}`, `.../events`, `.../trace` → `200` on success, `404` if the ID doesn't exist, `403` if the caller isn't authorized to view this specific task (data permissions apply per-task, not just per-endpoint — `security-architecture.md` §8.4).

## 11.3 Agent APIs

Inspect the agents making up the fleet.

```
GET /agents
GET /agents/{id}
```

Exposes the same fields defined in the Agent Registry (`runtime-agents.md` §3.3): ID, role, department, capabilities, tools, permissions, model, status, concurrency, health, version. `GET /agents/research-01` returns that agent's current state — letting the dashboard read off the health states already defined in `runtime-agents.md` §3.4 (`IDLE`, `RUNNING`, `WAITING`, `BLOCKED`, `DEGRADED`, `ERROR`, `OFFLINE`) rather than the API inventing its own status vocabulary.

**Status codes:** `GET /agents` → `200`, paginated per §11.1.1, filterable by `?department=`. `GET /agents/{id}` → `200` on success, `404` if the agent ID doesn't exist.

## 11.4 Session APIs

The execution context tied to a conversation or workflow.

```
GET /sessions/{id}
```

Returns session ID, user request, agent interactions, tool calls, task state, intermediate outputs — same shape as `memory.md` §6.2.2's Session Memory layer. Authorized clients inspect the context for one specific execution without exposure to unrelated sessions, which is the API-level expression of context isolation (`memory.md` §6.4): each session has its own execution context, and this endpoint provides controlled access to exactly that one context, nothing adjacent to it.

**Status codes:** `200` on success, `404` if the session doesn't exist, `403` if the caller isn't the session's owner or otherwise authorized — context isolation is enforced here, not just documented.

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

**Status codes:** `200` on success, `404` if the workflow doesn't exist.

## 11.6 Usage & Cost APIs

Token consumption and model usage, exposed for consumption without querying the underlying databases directly.

```
GET /usage
GET /costs
```

Tokens used, model usage, cost per task/agent/department/model, daily/monthly cost — the same fields `runtime.md` §7.4 defines as tracked and `observability.md` §10.3/§10.7 defines as aggregated. This endpoint is how that aggregation actually reaches a dashboard or an external reporting system.

**Status codes:** `200` on success (an empty/zeroed aggregation for a period with no activity is still `200`, not `404` — there's no "usage record" identity to be missing). `400` on an invalid date range or aggregation parameter. Both endpoints are paginated per §11.1.1 when returning a per-task/per-agent breakdown rather than a single aggregate.

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

This is the API surface for the approval gate already defined in `security-architecture.md` §8.7 and `workflow.md` §5.8 — the mechanism doesn't change here, this just gives a dashboard or another authorized interface a concrete way to act on it. Request/response fields match the `ApprovalRequest` entity (`security-architecture.md` §8.7.1).

**Status codes:** `200` + the updated `ApprovalRequest` on success. `404` if the approval ID doesn't exist. `409` if it's already resolved (`status` is no longer `PENDING`) — approving or rejecting an already-resolved request is a conflict, not silently accepted or repeated; this is also where the `Idempotency-Key` convention (§11.1.1) matters, so a genuine retry of the *same* approve call doesn't collide with this check. `403` if the caller isn't authorized to resolve this specific approval (e.g. not the designated approver).

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