# Orchestration & Task Management

The division of responsibility in one line: **the orchestrator decides what needs to be done; the router decides who should do it; the assigned agent performs the work.** These are three distinct responsibilities — collapsing any two of them onto one component is the mistake this document exists to prevent.

## 4.1 Executive Orchestrator

The Executive Orchestrator is a manager-level agent. It understands user requests, decomposes and delegates work to specialized agents, tracks their execution, collects their results, and produces the final outcome. It is responsible for *coordinating* the work, not performing it.

What it does, in order:

```
Incoming Request
      ↓
Understand Request
      ↓
Classify Task
      ↓
Break Down Complex Work
      ↓
Select Department
      ↓
Create Task
      ↓
Dispatch Task
      ↓
Track Execution
      ↓
Collect Results
      ↓
Request More Work if Needed
      ↓
Produce Final Result
```

**Example.** User asks: *"Research the wealth-management software market."* The orchestrator doesn't do the research itself:

```
User → Executive Orchestrator → Understand Request → Create Research Task
     → Research Agent → Research Result → Executive Orchestrator → Final Result
```

A more complex request may route through several agents this way before the orchestrator produces a final result.

**Important distinction:** the Executive Orchestrator is not another worker agent. It's a manager that retains control over the overall task while specialized agents perform bounded subtasks — see `runtime-agents.md` §3.1 for how this fits into the fleet model, and the note there resolving the CEO/Founder Orchestrator naming.

## 4.2 Deterministic Task Routing

Once the system understands what the user wants, the task has to reach the correct department and agent — that's the Task Router's job, not something left to whichever agent feels capable.

```
User Request: "Analyze wealth-management competitors"
       ↓
LLM Classification → TASK = MARKET_RESEARCH, DOMAIN = RESEARCH
       ↓
Deterministic Router
       ↓
Research Department → Market Research Agent
```

The LLM is useful for understanding natural language and classifying the request. The **application enforces the actual routing policy** — the LLM doesn't get to also decide where the task goes.

| Classification | Department | Agent |
|---|---|---|
| `MARKET_RESEARCH` | Research | `market_research_agent` |
| `SOFTWARE_DEVELOPMENT` | Engineering | `development_agent` |
| `TESTING` | QA | `qa_agent` |
| `SECURITY_AUDIT` | Security | `security_agent` |

**The rule:** an agent never decides which tasks it wants to handle. The platform determines where each task must go. LLM intelligence identifies the task; application logic enforces where it lands — which is what makes routing predictable in behavior, cost, and performance, rather than a matter of which agent happened to feel confident.

## 4.3 Department Ownership

Every task has a clearly assigned department and agent responsible for executing it. This is what prevents multiple agents from independently attempting the same task.

```
Task ID: TASK-82931
Department: Research
Assigned Agent: market-research-01
Status: RUNNING
Priority: HIGH
Created By: Executive Orchestrator
```

Once assigned, a task is executed only by the assigned agent, or an explicitly authorized substitute. Without this, the fleet degrades into agents racing each other:

```
Task
 ├── Research Agent   ──┐
 ├── Product Agent    ──┼── "I'll do it"
 └── Engineering Agent ─┘
```

Ownership replaces that with a single deterministic path:

```
Task → Research Department → market-research-01
```

## 4.4 Task Management

Tasks are the unit of work moving through the fleet. A simple request creates one task; a complex request can create a parent task with multiple child tasks (§4.4.4).

### 4.4.1 Task Queue

A durable intermediate layer sits between orchestration and execution — it stores and manages tasks, tracking lifecycle, retries, ownership, execution details, cost, and observability information.

```
Executive Orchestrator
        ↓
    Task Queue
        ↓
 ┌──────┼──────┐
 ↓      ↓      ↓
Research Engineering QA
Worker   Worker      Worker
```

The queue lets tasks wait until the appropriate agent or worker actually has capacity, and it's the foundation concurrent execution (§4.5) is built on.

### 4.4.2 Task Lifecycle

A task moves through defined states — this is how the platform always knows exactly where a task currently stands:

```
CREATED
   ↓
QUEUED
   ↓
ASSIGNED
   ↓
RUNNING ⇄ PENDING_APPROVAL          (a tool call inside the task needs human sign-off — §8.7)
   │           │
   │           └──→ FAILED   (rejected — a Policy rejection per §4.6, not a cancellation)
   │
   ├──→ COMPLETED
   ├──→ PARTIALLY_COMPLETED          (parent task only, mixed child outcomes — §4.4.4)
   ├──→ TIMED_OUT ──┐
   └──→ FAILED ──────┼──→ RETRY ──→ RUNNING
                      └──→ DEAD_LETTERED   (retry budget exhausted or explicitly non-retryable)

CANCELLED can be reached from any non-terminal state above
(CREATED, QUEUED, ASSIGNED, RUNNING, or PENDING_APPROVAL) — it is a deliberate
stop initiated by a human, the orchestrator, or a parent task, not a failure
and not the same thing as an approval being rejected.
```

| State | Meaning |
|---|---|
| `CREATED` | Task has been created, not yet queued |
| `QUEUED` | Waiting in the Task Queue (§4.4.1) for an available agent |
| `ASSIGNED` | A specific agent instance has been assigned, not yet started |
| `RUNNING` | Actively executing |
| `PENDING_APPROVAL` | Execution is paused because a tool call inside this task requires human approval before it can continue (`security-architecture.md` §8.7); resumes to `RUNNING` on approval, moves to `FAILED` (`Policy rejection`, §4.6) on rejection |
| `COMPLETED` | Finished successfully |
| `PARTIALLY_COMPLETED` | A parent task's child tasks (§4.4.4) finished with a mix of outcomes — some `COMPLETED`, some `FAILED`/`CANCELLED` — and the parent is returning a best-available result rather than treating the whole task as failed |
| `FAILED` | Finished unsuccessfully; classified per §4.6 (including a rejected approval, as `Policy rejection`) and either retried or escalated |
| `RETRY` | Being re-attempted after a `FAILED` or `TIMED_OUT` classification, per the agent's retry policy (`runtime-agents.md` §3.2) |
| `TIMED_OUT` | Exceeded its configured `Timeout` (§4.4.3) before finishing |
| `CANCELLED` | Stopped intentionally before completion — by a human, the orchestrator, or a parent task's own cancellation — not a failure, and not the outcome of a rejected approval (that's `FAILED`, above) |
| `DEAD_LETTERED` | Exhausted its retry budget (or was explicitly non-retryable) and is parked for manual inspection instead of being retried indefinitely |

**Why not `BLOCKED` / `AWAITING_APPROVAL` at the task level?** `runtime-agents.md` §3.4 already uses those exact names for *Agent Health State* — a different concept (can this agent instance make progress on anything right now?) from task lifecycle state (is this specific task progressing?). Reusing the same names here would make logs and dashboards ambiguous about which one a given state refers to. The task-level equivalent of "needs a human" is named `PENDING_APPROVAL` instead, and a generic task-level `BLOCKED` was deliberately not added — a task waiting on something is already represented by the states above (`QUEUED` before assignment, or the parent/child structure in §4.4.4), so a further state isn't warranted yet.

**Why does `TIMED_OUT` get its own state instead of folding into `FAILED` + an error-type field?** Every other failure type in §4.6 is a classification *within* `FAILED` (carried in the task's Error Information field, §4.4.3) rather than its own top-level state — timeout is the one exception, because it's common enough and operationally distinct enough (its own retry/backoff behavior, and dashboards/alerts routinely need to filter "did this time out" without unpacking an error-detail field) to be worth a first-class terminal state. This is a legibility trade-off, not a forced conclusion — reasonable to revisit once Phase 4's durable queue and retry infrastructure is actually built and real timeout volume is observed.

### 4.4.3 Task Metadata

A task carries enough information for the fleet to track and manage it — useful for execution, but just as much for monitoring, debugging, cost tracking, and auditing. This is the `Task` entity's field reference; `TaskStatus` is the enum defined in §4.4.2.

| Field | Type | Required | Purpose |
|---|---|---|---|
| Task ID | string | yes | Unique identifier |
| Parent Task ID | string | no | Links a child task back to its parent (§4.4.4) |
| Department | string | yes | Owning department |
| Assigned Agent | agent instance ID | no (set on `ASSIGNED`) | Owning agent instance |
| Priority | enum: `LOW`, `NORMAL`, `HIGH` | yes | Scheduling weight |
| Status | `TaskStatus` (§4.4.2) | yes | Current lifecycle state |
| Retry Count | number | yes (defaults 0) | How many retries have occurred |
| Created At / Started At / Completed At | timestamp | Created At: yes; others: only once reached | Timestamps |
| Timeout | number (ms) | yes | Maximum allowed execution time before moving to `TIMED_OUT` |
| Cost | number | yes (defaults 0) | Accumulated cost for this task |
| Token Usage | number | yes (defaults 0) | Accumulated token consumption |
| Error Information | object (failure type per §4.6, message, stack/trace ref) | only on `FAILED`/`TIMED_OUT`/`DEAD_LETTERED` | Populated on failure |
| Trace ID | string | yes | Links to the distributed trace |

Full detail on how cost and token usage are actually tracked and aggregated lives in `memory.md` and `observability.md` — this table is what a task carries, not how the platform rolls it up.

### 4.4.4 Task Hierarchy

Complex work is decomposable: a parent task splits into child tasks, each executed independently, with the parent orchestrator combining their results into the final outcome.

```
TASK-100 "Evaluate wealth-management software market"
├── TASK-101  Market Research
├── TASK-102  Competitor Analysis
├── TASK-103  Pricing Analysis
└── TASK-104  Technology Analysis
```

Each child task gets its own agent, session, execution context, status, and results. Instead of one giant task forced onto one agent:

```
One giant task → One agent
```

the work fans out and recombines:

```
                Parent Task
                    ↓
      ┌─────────────┼─────────────┐
      ↓              ↓              ↓
  Research      Competitors      Pricing
      ↓              ↓              ↓
      └─────────────┼─────────────┘
                    ↓
              Final Result
```

## 4.5 Concurrency

The fleet executes multiple tasks simultaneously via asynchronous execution and task queues, with configurable concurrency limits per department — rather than waiting for one task to finish before starting the next.

```
                Orchestrator
        ┌───────────┼───────────┐
        ↓            ↓            ↓
    Research     Engineering      QA
     Task A         Task B      Task C
    RUNNING        RUNNING     RUNNING
```

This runs on asynchronous execution, a task queue, independent workers, and configurable concurrency limits:

| Department | Concurrent tasks |
|---|---|
| Research | 5 |
| Engineering | 10 |
| QA | 5 |
| Security | 3 |

These are configuration values, not fixed architectural constants — tune them per department's actual load, don't hardcode them as if they were structural.

**Why it matters:** concurrency is what keeps a single agent or department from becoming a bottleneck for the whole fleet's throughput.

## 4.6 Failure Handling

A failed task does not mean the agent itself has permanently failed. The platform classifies the failure and applies the matching recovery strategy:

```
Agent → Task → FAILURE → Retry Policy
                            ├── Retry
                            ├── Reassign
                            ├── Escalate
                            └── Human Intervention
```

| Failure type | Meaning |
|---|---|
| Transient | Temporary problem — likely retry |
| Permanent | Cannot succeed as currently configured — may need reassignment or escalation |
| Tool failure | The external tool failed |
| Model failure | The LLM/model request failed |
| Policy rejection | Blocked by a policy or guardrail |
| Timeout | Took longer than the allowed execution time |
| Resource exhaustion | Required resources weren't available |
| Invalid output | Output didn't meet the expected format/requirements |

This is what lets the platform decide what happens next instead of treating every failure identically — a policy rejection and a transient network blip are not the same event and shouldn't trigger the same response. Retry/timeout policy defaults are set per-agent in the agent definition (`runtime-agents.md` §3.2); this is where those defaults actually get exercised at the task level.

In terms of the task lifecycle (§4.4.2): a `Timeout` failure moves the task to `TIMED_OUT`; every other failure type here moves it to `FAILED`. Both are eligible for the `RETRY` transition unless the failure is classified `Permanent` or the retry budget is already exhausted, in which case the task moves to `DEAD_LETTERED` instead of retrying indefinitely.

## 4.7 Agent-to-Agent Collaboration

Agents can work with each other, but not by freely calling whichever agent they want.

```
Research Agent → needs technical analysis → Engineering Agent
```

The Research Agent does **not** invoke Engineering Agent directly. Instead:

```
Research Agent
      ↓
"Technical feasibility is required"
      ↓
Collaboration Request
      ↓
Orchestrator / Workflow Engine
      ↓
Engineering Agent
      ↓
Feasibility Analysis
```

The orchestrator/workflow layer checks: is this collaboration allowed, is Engineering the correct agent, is the Research Agent authorized to request it, and what task should Engineering actually perform. This creates an auditable chain of what happened, and lets the fleet apply its own authorization and routing policy around every handoff rather than trusting agents to self-regulate. Full detail on how that authorization is enforced lives in `security-architecture.md`.