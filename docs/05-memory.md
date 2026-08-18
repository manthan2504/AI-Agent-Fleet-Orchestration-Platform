# Memory & Context Architecture

The fleet has access to a large amount of organizational information, but sharing everything with every agent is not the goal. The core distinction, stated once here and referenced everywhere else: **knowledge is shared; execution context is isolated.** An agent retrieves the organizational information it actually needs, without receiving every document, conversation, tool result, and private working state in the system.

> This is the full implementation-level treatment of `overview.md`'s principles #1 and #2. That doc states the principle; this one covers the mechanism.

## 6.1 Shared Knowledge vs. Shared Context

"All agents should know everything" does **not** mean every agent receives the complete organizational memory on every request.

Given company documentation, product information, technical decisions, research reports, policies, historical decisions, and engineering knowledge, we don't want:

```
Research Agent → EVERYTHING → Huge Prompt
```

Instead:

```
          ORGANIZATIONAL KNOWLEDGE
                    │
    ┌───────────────┼───────────────┐
    ↓                ↓                ↓
Research          Product          Engineering
    └───────────────┼───────────────┘
                    ↓
              Retrieval Layer
                    ↓
             Relevant Information
```

The agent retrieves only what's relevant and authorized for its task. This reduces token consumption, prompt size, latency, context-window pressure, information leakage, and unnecessary cost — and tends to improve reasoning quality too, since the agent is working from focused information instead of a haystack.

## 6.2 Memory Architecture

Memory splits into layers because different information has different lifetimes and ownership:

```
Memory Architecture
├── Working Memory
├── Session Memory
├── Agent Memory
├── Organizational Memory
└── Episodic Memory
```

| Layer | Scope | Think of it as |
|---|---|---|
| **Working Memory** (§6.2.1) | One active task | The agent's temporary workspace |
| **Session Memory** (§6.2.2) | One conversation/workflow session | The history of one interaction |
| **Agent Memory** (§6.2.3) | One agent/department, long-term | The agent's professional experience |
| **Organizational Memory** (§6.2.4) | Shared, authorized agents | The org's central knowledge base |
| **Episodic Memory** (§6.2.5) | Historical events, timestamped | The org's historical timeline |

### 6.2.1 Working Memory

Temporary information required while a task executes — research sources, intermediate findings, current task state, temporary files, tool results. Belongs to the active task/session; doesn't automatically become long-term organizational knowledge.

```
TASK-82931
├── Research Sources
├── Intermediate Findings
├── Current Task State
├── Temporary Files
└── Tool Results
```

### 6.2.2 Session Memory

Context tied to one particular conversation or workflow session — user request, agent interactions, tool calls, task state, intermediate outputs. Isolated from unrelated sessions by design.

```
SESSION-1829
├── User Request
├── Agent Interactions
├── Tool Calls
├── Task State
└── Intermediate Outputs
```

### 6.2.3 Agent Memory

Longer-term information specific to one agent or department — research methodology, previous projects, preferred sources, department procedures. Lets an agent retain domain-specific knowledge across tasks rather than relearning it every time.

```
Research Agent Memory
├── Research Methodology
├── Previous Research Projects
├── Preferred Research Sources
└── Department Procedures
```

> **This project already has a working instance of this concept**, at a different layer: each `.claude/agents/*.md` dev-loop agent (researcher, architect, implementer, reviewer, security) has `memory: project` enabled, giving it a persistent `MEMORY.md` for exactly this purpose — conventions, gotchas, prior decisions specific to that role. That's Agent Memory applied to the agents *building* the platform. This section describes the same concept applied to the platform's own *runtime* agents once they exist. Same pattern, two different layers — don't conflate them.

### 6.2.4 Organizational Memory

Knowledge shareable across authorized agents — company architecture, products, documentation, technical decisions, policies, market research, historical reports.

```
Organizational Memory
├── Company Architecture
├── Products
├── Company Documentation
├── Technical Decisions
├── Policies
├── Market Research
└── Historical Reports
```

"Shared" still means access-controlled — not every agent can reach everything in here without authorization. See `security-architecture.md` for how that authorization is actually enforced.

> **`docs/decisions/` is a working instance of "Technical Decisions" in this layer** — every ADR-style entry in that folder is exactly the kind of record this section describes, just implemented for the humans and dev-loop agents building the system rather than the runtime fleet.

### 6.2.5 Episodic Memory

Important historical events or experiences, recorded as a timeline — distinct from general organizational knowledge because it's specifically about *what happened*, not standing facts.

```
2026-08-10: Engineering completed Unified API migration.
2026-08-09: Research team completed wealth-management analysis.
```

> This is also already implemented at the dev-loop layer: `implementer.md` and `reviewer.md` are both instructed to log a short, dated line for meaningful completed work in their own `MEMORY.md` — the same episodic pattern, one level down.

## 6.3 Memory Retrieval

The platform retrieves rather than injecting the entire memory into every prompt — selectively fetching the most relevant, authorized organizational knowledge for the agent's current task.

```
Agent receives Task
       ↓
Determine Required Knowledge
       ↓
Memory Retrieval
       ↓
Relevant Context
       ↓
Agent
```

The memory layer needs to support:

| Capability | Purpose |
|---|---|
| Semantic search | Find information by meaning, not just keyword match |
| Metadata filtering | Filter on document properties |
| Department filtering | Retrieve relevant department knowledge |
| Permissions | Only retrieve what the agent is authorized to access — see `security-architecture.md` |
| Recency | Prefer newer information when appropriate |
| Relevance scoring | Rank results by usefulness |
| Source attribution | Know where retrieved information came from |
| Document versioning | Distinguish between versions of the same information |

**Why:** avoiding huge prompts → unnecessary tokens → higher cost → slower execution → worse context management. Full detail on how this gets measured lives in `observability.md`.

**Example** — an Engineering Agent working an API task retrieves:

```
Relevant:        API architecture, technical decisions, engineering documentation
Probably not:    Sales reports, marketing campaigns, unrelated research
```

## 6.4 Context Isolation

Every task maintains its own session and working context — private information from one task or agent doesn't accidentally leak into another, while shared organizational knowledge stays accessible.

```
TASK-A: Research Agent    → Session A → Memory A
TASK-B: Engineering Agent → Session B → Memory B
TASK-C: QA Agent          → Session C → Memory C
```

All three can reach shared organizational knowledge:

```
        Shared Organizational Knowledge
           ↙          ↓          ↘
       Task A      Task B      Task C
```

But they must not inherit each other's private working context:

```
Task A: Temporary Research Files, Private Tool Results, Intermediate Reasoning
              │
              │  must NOT leak into
              ↓
Task B
```

**Why it matters:** if Research and Engineering tasks run concurrently, the Engineering Agent must not accidentally receive the Research Agent's temporary findings, session history, or private task data. This gets more important, not less, as more tasks run concurrently — see `orchestration.md` §4.5.

## 6.5 Context Optimization

Actively minimizing unnecessary information sent to the model — filtering, summarization, retrieval, compaction, model selection, caching, structured communication — to cut tokens, cost, and latency. Don't send the model more than it actually needs.

| Strategy | What it does |
|---|---|
| Context Filtering | Only provide information relevant to the current task |
| Summarization | Compress long histories instead of resending them whole |
| Memory Retrieval | Retrieve relevant knowledge instead of the full knowledge base (§6.3) |
| Session Compaction | Summarize older conversation turns once a session grows large |
| Model Routing | Match model to task requirements rather than defaulting to the most expensive one |
| Cached Context | Reuse repeated context where supported |
| Structured Outputs | Use structured data for intermediate communication instead of full natural language when it isn't needed |

```
Less Unnecessary Context
        ↓
  Lower Token Usage
        ↓
     Lower Cost
        ↓
   Lower Latency
        ↓
More Focused Agent Execution
```