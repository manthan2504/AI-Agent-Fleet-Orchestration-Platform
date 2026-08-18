---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "package.json"
---

# Technology Stack

Full rationale and alternatives considered: `docs/decisions/0001-dashboard-and-platform-tech-stack.md`. This file is the operational version — what to actually do, not why.

## Fleet Platform backend

- Node.js + TypeScript. Fastify or Express.
- BullMQ on Redis for the task queue/worker model — don't hand-roll a custom queue.
- PostgreSQL for all operational state: tasks, agents, sessions, permissions, workflows, approvals, costs.

## Fleet Dashboard

- Next.js, App Router. Not a separate SPA + API pair. Not MERN.
- React Server Components by default. Client Components (`"use client"`) only where there's real interactivity or a live connection — live task view, workflow graph, real-time agent status. Don't default to client-side rendering for read-heavy views (agent registry, cost tables, historical logs) just because it's simpler to write.
- shadcn/ui (Radix + Tailwind) for components.
- Prisma or Drizzle, against the same PostgreSQL instance the platform backend uses — one database engine, not two.
- Real-time views need a dedicated WebSocket/SSE layer. Don't hold persistent connections inside Next.js API routes, and don't fall back to polling for things that are supposed to feel live.

## Hard rule

Never introduce MongoDB or any document store for operational data (tasks, agents, permissions, workflows, approvals, costs). That data is relational by design — see `docs/persistence.md` §9.2. This isn't a style preference open to reconsideration per-task; it's already decided.