# 0001: Platform & Dashboard Technology Stack

## Status

Accepted

## Context

Two distinct components need separate stack decisions, not one shared answer:

- The **Fleet Platform backend** — task queue, orchestrator, workers, OpenClaw integration — is the actual heavy async work (`orchestration.md` §4.4.1).
- The **Fleet Dashboard** — a multi-user web UI for monitoring — is a consumer of the Fleet API and Event Bus (`api.md`, `observability.md` §10.4), not where the heavy lifting happens.

Relevant constraints already decided elsewhere in `docs/`:

- OpenClaw's own SDK is TypeScript-based (`runtime.md` §7.1), weighing toward a TypeScript-native backend for straightforward integration.
- `persistence.md` §9.2 already commits to a relational database for operational state — tasks, agents, sessions, permissions, workflows, approvals, costs — data that needs joins, foreign keys, and transactional consistency.
- The dashboard needs real-time updates (live task view, workflow graph, live agent status — `observability.md` §10.6–§10.7) and multiple concurrent team members with distinct auth/authz.

## Decision

**Fleet Platform backend:** Node.js + TypeScript service (Fastify or Express), BullMQ on Redis for the task queue/worker model, PostgreSQL for the relational store.

**Fleet Dashboard:** Next.js (App Router) + React — not a MERN stack, not a separate SPA-plus-API-service pair.

- React Server Components by default, for read-heavy non-interactive views (agent registry, cost tables, historical logs).
- Client Components (`"use client"`) only where actual interactivity or a live connection is needed — live task view, workflow graph, real-time agent status.
- shadcn/ui (Radix + Tailwind) for the component layer.
- Prisma or Drizzle as the ORM, against the **same** PostgreSQL instance the platform backend uses.

## Alternatives Considered

- **MERN (MongoDB + Express + React + Node).** Rejected. MongoDB doesn't fit the relational, transactional operational-state model already committed to in `persistence.md` §9.2. Adopting it would mean running a second, mismatched database purely for the dashboard's convenience, against data that's explicitly relational by design.
- **Plain Express API + separate React SPA for the dashboard.** Rejected in favor of Next.js as a combined BFF-plus-frontend — avoids standing up and maintaining a whole second API service just to serve the dashboard, and gets Server Components for the data-heavy views without extra infrastructure.

## Consequences

- If the still-open vector database decision (`persistence.md` §9.3) lands on pgvector, platform and dashboard end up sharing one database engine (PostgreSQL) for both operational and semantic storage. This is a reason to weight that open decision toward pgvector — not a conclusion it forces.
- Real-time dashboard views need a dedicated WebSocket/SSE layer. Next.js API routes don't hold persistent connections well on their own — this is a component still to be designed, not something this decision resolves.
- The operational version of this decision — the part an implementing agent actually has to follow — lives in `.claude/rules/tech-stack.md`. This document is the rationale; that one is the enforced rule.

## References

`runtime.md` §7.1 · `persistence.md` §9.2, §9.3 · `orchestration.md` §4.4.1 · `observability.md` §10.6, §10.7 (Dashboard Build Scope) · `api.md`

---

*Housekeeping note: the OpenClaw-over-OpenAI-Agents-SDK choice (`runtime.md` §7.1) was made earlier in this project than this decision but was never formally logged here. It should arguably be `0001` with this one renumbered to `0002` — flagging rather than silently choosing an order. Worth a quick decision on which numbering you want before a third entry makes it awkward to fix.*