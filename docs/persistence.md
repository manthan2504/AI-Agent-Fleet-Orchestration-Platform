# Persistence & Data Architecture

Where the fleet stores its operational data, organizational knowledge, and generated artifacts. The core architectural decision: **separate different types of data instead of putting everything into one database.**

```
AI Agent Fleet
      │
Persistence Layer
      │
      ├── Relational Database
      ├── Vector Database
      └── Object Storage
```

Each store has a different responsibility — this is a deliberate three-way split, not three options to pick from.

## 9.1 Persistence Layer

Responsible for storing information that needs to survive beyond a single agent execution, split by purpose:

```
Persistence
├── Operational State        → Relational Database
├── Semantic Knowledge       → Vector Database
└── Files & Large Artifacts  → Object Storage
```

The key idea: don't put every kind of data into one storage system. Operational data, searchable knowledge, and large files each want a different access pattern, and forcing them into one store fights that.

## 9.2 Relational Database

Stores the fleet's structured operational state — the things the platform needs to query, update, and manage reliably:

Agents · Tasks · Sessions · Users · Permissions · Workflows · Approvals · Usage · Costs · Events

**Example:**

```
TASK-82931
Department: Research
Agent: market_research
Status: RUNNING
Priority: HIGH
Created At: <timestamp>
```

```
                Relational DB
                     │
   ┌─────────────────┼─────────────────┐
 Agents             Tasks            Sessions
   │                   │                  │
Permissions        Workflows           Users
   │                   │                  │
Approvals            Usage              Costs
```

This is `runtime-agents.md`'s Agent Registry, `orchestration.md`'s tasks/workflows/approvals, and `security-architecture.md`'s permissions — all structured, all queryable, all belonging here specifically because they're operational state, not knowledge.

## 9.3 Vector Database

Used for semantic knowledge and memory retrieval — finding information by meaning rather than exact keyword match:

Company Documentation · Product Knowledge · Technical Decisions · Research · Historical Reports · Agent Memories

```
Agent → "What do we know about this topic?" → Vector Search → Relevant Knowledge → Agent Context
```

An Engineering Agent working an API task retrieves the relevant technical documentation without receiving the entire company knowledge base along with it.

**This is the physical implementation of the memory architecture already described conceptually in `memory.md`** — that document covers *what* the memory layers are (working, session, agent, organizational, episodic) and how retrieval should behave (§6.3); this is *where organizational and episodic memory actually live*:

```
Organizational Memory → Vector Database → Semantic Retrieval → Relevant Context → Agent
```

> **Open question, not yet resolved:** the source spec doesn't specify which vector database technology this actually runs on (options span dedicated vector DBs, or a relational extension like pgvector). That's a real architectural decision, not a detail to assume — route it through `architecture-review`, and once decided, it belongs in `docs/decisions/` as its own dated entry, the same way the OpenClaw runtime choice does.

## 9.4 Object Storage

For files, artifacts, and large outputs — not structured operational records:

Reports · Files · Artifacts · Logs · Large Outputs · Generated Documents

```
Research Agent → Generate Research Report → Object Storage → research-report-82931.pdf
```

Large documents don't go directly into the relational database — the file lives in object storage, and the relational DB keeps a reference to it:

```
Relational DB
└── File Metadata / Reference
         │
         ↓
Object Storage
└── Actual File
```

## How the Three Work Together

Complementary, not competing:

```
                           AI FLEET
                              │
                     Persistence Layer
                              │
        ┌─────────────────────┼─────────────────────┐
   Relational DB            Vector DB            Object Storage
        │                       │                       │
  Operational State      Knowledge/Memory         Files/Artifacts
        │                       │                       │
  Tasks, Agents,           Documents,               Reports,
  Sessions, Users          Research,                Generated Files
  Permissions              Memories                 Large Outputs
```

A single task typically touches all three at once:

```
TASK-8293
├── Relational DB    → task status, agent, timestamps
├── Vector DB        → relevant company/research knowledge
└── Object Storage   → generated research report
```

This separation is what gives the fleet a data architecture that stays clean as it scales, instead of one database straining under operational queries, semantic search, and large file storage all at once.