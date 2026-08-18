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
RUNNING
   ├──→ COMPLETED
   │
   └──→ FAILED
          ↓
        RETRY
          ↓
        RUNNING
```

### 4.4.3 Task Metadata

A task carries enough information for the fleet to track and manage it — useful for execution, but just as much for monitoring, debugging, cost tracking, and auditing:

| Field | Purpose |
|---|---|
| Task ID | Unique identifier |
| Parent Task ID | Links a child task back to its parent (§4.4.4) |
| Department | Owning department |
| Assigned Agent | Owning agent instance |
| Priority | Scheduling weight |
| Status | Current lifecycle state (§4.4.2) |
| Retry Count | How many retries have occurred |
| Created At / Started At / Completed At | Timestamps |
| Timeout | Maximum allowed execution time |
| Cost | Accumulated cost for this task |
| Token Usage | Accumulated token consumption |
| Error Information | Populated on failure |
| Trace ID | Links to the distributed trace |

Full detail on how cost and token usage are actually tracked and aggregated lives in `memory-and-observability.md` — this table is what a task carries, not how the platform rolls it up.

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