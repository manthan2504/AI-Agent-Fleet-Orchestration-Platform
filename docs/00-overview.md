# Overview

## 1. Purpose

The AI Agent Fleet & Orchestration Platform is a production-grade multi-agent system built to operate like a virtual organization — not one general-purpose agent handling every kind of work, but a fleet of specialized agents, each responsible for a specific organizational function (Research, Product, Engineering, QA, Security, and more as the fleet grows).

The platform is responsible for:

- Understanding incoming requests.
- Routing tasks to the correct department and agent.
- Coordinating multiple agents when a task is complex.
- Providing agents with relevant organizational knowledge.
- Keeping task execution contexts isolated.
- Controlling tools, permissions, and external actions.
- Supporting concurrent task execution.
- Tracking usage, cost, logs, metrics, and traces.
- Providing a central interface for monitoring the fleet.

The goal is not a collection of AI chatbots. It's a coordinated system where specialized agents work together under controlled orchestration.

## 2. What Is an AI Agent Fleet

A fleet is a collection of specialized agents working as an organized system, not a set of independent assistants. Each agent represents a specific organizational role — Engineering, QA, Security, Research, Marketing, and so on.

```
AI AGENT FLEET
│
├── Executive Orchestrator
├── Research Agent
├── Product Agent
├── Engineering Agent
├── QA Agent
├── Security Agent
├── Sales Agent
├── Marketing Agent
└── DevOps Agent
```

> This is the fleet's eventual full shape, not what exists today. See `runtime-agents.md` for which agents are actually in scope at the current build phase — don't treat this list as already built.

Each agent has its own role, department, capabilities, tools, permissions, model policy, memory policy, and session/context policy.

The Executive Orchestrator coordinates the fleet: it understands the incoming request, breaks complex work into tasks, and dispatches those tasks to the appropriate specialized agents.

**Example.** A user asks: *"Analyze the wealth-management software market and determine which technical capabilities our product should prioritize."*

```
User
 ↓
Executive Orchestrator
 ↓
Research Agent → Market Research
 ↓
Product Agent → Product Recommendations
 ↓
Engineering Agent → Technical Feasibility
 ↓
Executive Orchestrator
 ↓
Final Result
```

The fleet behaves like an AI organization, not a collection of separate chatbots: a coordinated set of specialized agents, each responsible for a bounded organizational role, operating under central orchestration.

## 3. Why a Fleet, Not One Agent

A single general-purpose agent *can* perform many different tasks, but using one agent for everything — Research, Product, Engineering, QA, Security, Sales, Finance, DevOps all at once — creates architectural problems:

- **Context overload** — too much unrelated information in play at once.
- **Poor specialization** — one agent expected to perform every role well.
- **Concurrency bottlenecks** — all work concentrates around a single point.
- **Permission complexity** — the agent ends up with access to tools it doesn't need for most of what it does.
- **Higher token usage** — unnecessary context inflates model consumption.
- **Reduced control** — hard to enforce clear ownership of any given task.

The fleet solves this by dividing responsibility: one orchestrator breaks a problem into pieces and routes each piece to the domain-specific agent that owns it.

## 4. Core Architectural Principles

**1. Knowledge is shared.** Authorized agents can retrieve from a common organizational knowledge layer — company documentation, policies, technical decisions, historical research, product information. The full knowledge base is never injected into every prompt; agents retrieve only what's relevant to the task in front of them.

**2. Execution context is isolated.** Every task and session gets its own working context.

```
Task A → Research Agent   → Session A → Context A
Task B → Engineering Agent → Session B → Context B
```

**3. Task ownership is explicit.** Every task has one clear owner.

```
TASK-82931
Department: Research
Agent: market-research-01
Status: RUNNING
```

This prevents multiple agents from independently attempting the same task.

**4. Actions are controlled.** Agents don't get unrestricted access to tools or infrastructure. Tools, permissions, agent handoffs, external actions, and production operations all route through the platform's security and policy mechanisms.

**Core principle, in one line:** *Knowledge is shared; execution context is isolated; task ownership is explicit; actions are controlled.*

> This is the narrative version. The condensed, always-loaded operational version that every dev-loop agent actually carries in context session-to-session lives in `.claude/rules/architecture.md` — same four principles, no duplication of reasoning, just the working reference.

## 5. Anti-Pattern to Avoid

Don't build the "one giant agent." It becomes responsible for too many roles, tools, permissions, knowledge domains, and tasks at once — a context and concurrency bottleneck by construction.

Build specialized agents instead, coordinated through an orchestration layer where the orchestrator coordinates and specialized agents perform the actual domain-specific execution.

**Key takeaway:** don't build one powerful agent that tries to do everything. Build specialized agents and coordinate them.