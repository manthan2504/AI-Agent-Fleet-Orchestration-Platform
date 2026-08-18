# Workflow Architecture

A **task** is a unit of work. A **workflow** is how multiple tasks are coordinated to reach a larger objective. They're related but not the same thing — a task can be internally decomposed into a hierarchy of child tasks (`orchestration.md` §4.4.4), while a workflow is the execution logic that governs *how* a set of tasks runs: in what order, in parallel or not, and what happens when one of them fails or needs a human to weigh in.

Simple requests may need only one task:

```
User → Research Agent → Result
```

Complex requests need several agents and tasks working together, coordinated as a workflow:

```
User → Executive Orchestrator → Research → Product → Engineering → QA → Security → Final Result
```

The **Workflow Engine** is the component responsible for coordinating that larger execution flow.

## 5.1 Workflow Engine

Coordinates multi-step agent workflows: task execution order, parallelism, conditions, dependencies, retries, timeouts, approvals, cancellation, and resumption.

It determines:

- Which task executes first.
- Which tasks can run in parallel.
- Which task depends on another.
- What happens when a task fails.
- When human approval is required.
- Whether the workflow continues, pauses, retries, or stops.

```
Workflow
├── Task A
├── Task B
├── Task C
└── Task D
```

The Workflow Engine doesn't perform the actual work — agents execute tasks, the engine coordinates them. How it's actually implemented on OpenClaw is covered in `runtime.md`; this document describes the coordination logic itself.

## 5.2 Sequential Execution

Some tasks must happen one after another because a later task depends on an earlier task's result.

```
Research → Product Analysis → Engineering Feasibility → QA
```

Engineering may need the Product Agent's output before it can start. So:

```
Task A → Task B → Task C → Task D
```

The workflow waits for each required step before continuing to the next.

## 5.3 Parallel Execution

Not every task depends on another. Independent tasks execute at the same time instead of waiting in a line:

```
                    Parent Task
                        │
        ┌───────────────┼───────────────┐
        ↓                ↓                ↓
    Research         Competitor        Pricing
     Task A            Task B           Task C
    RUNNING           RUNNING          RUNNING
        └───────────────┼───────────────┘
                        ↓
                 Combined Result
```

Instead of `Research → Competitor → Pricing` run strictly in sequence, running them in parallel reduces unnecessary waiting and makes better use of the fleet's concurrency (`orchestration.md` §4.5).

## 5.4 Conditional Branching

A workflow can make decisions based on an earlier task's result — it doesn't always follow one fixed path.

```
Analysis
   ↓
Is Risk High?
  ├── YES → Security Review
  └── NO  → Continue Workflow
```

The result of one task determines which task runs next.

## 5.5 Dependencies

A task can depend on another task completing first — dependencies define the relationships between tasks.

```
Research → Product Requirements → Engineering → QA
```

Engineering depends on Product Requirements; QA depends on Engineering. The Workflow Engine uses these relationships to determine when a task actually becomes eligible to run, rather than just executing tasks in creation order.

## 5.6 Retries & Timeouts

**Retry:** if a task fails, execute it again per its configured retry policy.
**Timeout:** stop or handle a task that exceeds its allowed execution time.

```
Task → Failure → Retry Policy
                    ├── Retry
                    ├── Reassign
                    ├── Escalate
                    └── Stop

Task → Timeout → Workflow Decision
                    ├── Retry
                    ├── Reassign
                    └── Escalate
```

This is the workflow-level view of the same failure classification covered in `orchestration.md` §4.6 — that document covers *how* a failure gets classified (transient, permanent, tool, model, policy rejection, timeout, resource exhaustion, invalid output); this is *what the workflow does* once a task in it fails or times out. Workflows need defined policies here, not indefinite waiting. `Reassign` here follows the same eligibility `orchestration.md` §4.6 defines at the task level — it isn't a separate escape hatch for a task the underlying classification already marked `DEAD_LETTERED` (`Permanent`, or `Policy rejection` including a rejected/timed-out approval); those go to `Escalate`/`Stop`, not `Reassign` or `Retry`, at the workflow level too.

## 5.7 Cancellation & Resumption

**Cancellation:** stop a running workflow when requested.

```
Workflow
  Research ✓
  Engineering RUNNING
       ↓
Cancellation Requested
       ↓
Workflow STOPPED
```

`STOPPED` is the workflow's own terminal state, distinct from `orchestration.md` §4.4.2's task-level `CANCELLED` — a workflow stopping is what causes its still-running child tasks to move to `CANCELLED` individually, not a renaming of the same state at a different scope. A completed child task (like Research above) keeps its `COMPLETED` status; only tasks still in flight when cancellation lands (like Engineering above) move to `CANCELLED`.

**Resumption:** continue a previously paused or interrupted workflow from the appropriate point, rather than restarting from the beginning.

```
Workflow
  Task A ✓
  Task B ✓
  Task C — interrupted
       ↓
     Resume
       ↓
  Task C → Task D
```

Particularly valuable for long-running workflows, where restarting from scratch would waste already-completed work.

**A task that reached `DEAD_LETTERED` is not "interrupted" in the sense this section means.** `Task C — interrupted` above implies a task that can still make progress once resumed; a `DEAD_LETTERED` task (`orchestration.md` §4.4.2/§4.6 — retry budget exhausted, or a `Permanent`/`Policy rejection` failure that was never retry-eligible in the first place) is terminal. Resuming a workflow past a `Permanent` dead-letter means routing around it — skip, escalate, or restart just that branch as a new task — not resuming the same task instance.

**A `Policy rejection` dead-letter is narrower still: "restart as a new task" is explicitly not an option for it, the same way §5.6 already excludes it from `Retry`/`Reassign`.** A fresh task raises a fresh `tool_call_id` and a fresh `ApprovalRequest` — it doesn't auto-execute anything a human hasn't seen — but re-requesting the identical rejected action under a new task ID is a re-ask, not a resumption, and nothing here currently limits how many times that can happen or signals to the next approver that this was already said no to once. Available options for this specific case are `Escalate` or `Stop` only, matching §5.6/§8.7's "full stop, no fallback path."

## 5.8 Human Approval

Some workflow actions are too sensitive to execute automatically:

- Production deployment
- Database deletion
- Financial transaction
- Credential rotation
- Infrastructure destruction
- External communication

The workflow pauses for approval before proceeding:

```
Agent → Tool Request → Risk Evaluation → Human Approval Required
                                             ├── APPROVED → Execute
                                             └── REJECTED → Stop
```

"Stop" here is the task-level outcome, not automatically the whole workflow's: the specific task moves to `FAILED` (`Policy rejection`) → `DEAD_LETTERED`, non-resumable, per `orchestration.md` §4.4.2/§4.6. Whether the *workflow* also stops (moves to `STOPPED`, §5.7) or continues with its other, independent branches depends on whether the rejected task was on the workflow's critical path — that's this document's existing dependency/branching mechanism deciding, not a new rule. Not resolved further here; flagging so this isn't read as "one rejection always halts the whole workflow" when the dependency structure might say otherwise.

This makes human intervention an explicit, first-class step inside the workflow itself — not an informal check happening somewhere outside the system where it can be silently skipped. Full detail on how approval gates are enforced (and which actions are non-negotiably gated, regardless of workflow urgency) lives in `security-architecture.md`.