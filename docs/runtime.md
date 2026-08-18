# Model & Agent Runtime

The architecture separates two responsibilities: the **Agent Runtime** executes individual agents; the **Fleet Management layer** controls how the overall fleet operates. That separation holds regardless of which runtime sits underneath it — the section below is about what changed when the runtime changed.

## 7.1 OpenClaw Agent Runtime

> **Correction from the source spec — read this before anything else in this section.**
> The original reference architecture recommended the OpenAI Agents SDK as the agent runtime, and claimed it provides agents, tools, handoffs, guardrails, sessions, and runners as ready-made primitives. **This project uses OpenClaw instead**, and OpenClaw is not a drop-in replacement for that claim. OpenClaw is a self-hosted, model-agnostic automation runtime built around **skills**, **event subscriptions**, and an **agent loop** (the source spec's inherited phrase "action loop" is not OpenClaw's own term — see verified findings below), with its own `plugin-sdk` — a different shape than an SDK purpose-built for manager/handoff multi-agent orchestration.
>
> The specific primitive list below (agents / tools / handoffs / guardrails / sessions / runners) describes what the OpenAI Agents SDK actually provides, not what's confirmed for OpenClaw. **Nothing in the Fleet Manager should be built assuming OpenClaw supplies these for free** until each one is checked against OpenClaw's actual API. Treat every mention of "the runtime provides X" past this point as *inherited language from the source spec*, flagged, not as a verified fact about OpenClaw.
>
> **This has now been checked once, directly against OpenClaw's official docs (`docs.openclaw.ai`) and its GitHub repo (`github.com/openclaw/openclaw`) — see "Verified findings" below.** One important correction to the paragraph above itself: the claim that skills are "WASM-sandboxed... and cryptographically verified on install" is **not accurate**. Details follow.

### Verified findings (research pass, 2026-08-18)

Verified against `docs.openclaw.ai` (official docs) and `github.com/openclaw/openclaw` (official repo, org confirmed as the same project — no name-collision risk found). Where independent corroboration existed it's cited too.

**1. Skills — corrects the inherited claim above.**
- Skills are **not WASM-sandboxed**. A skill is a `SKILL.md` file (YAML frontmatter + markdown body) that gets injected as a compact XML block into the agent's system prompt — it's a prompt-engineering artifact ("a repeatable workflow, review rubric, command sequence, or operating constraint"), not an isolated execution runtime. Source: [docs.openclaw.ai/tools/skills](https://docs.openclaw.ai/tools/skills).
- "Manifest-driven" is roughly right in spirit — skills load via a six-tier precedence system (workspace → project → personal → managed → bundled → plugin/extra dirs) and are declared via frontmatter — but the manifest is lightweight YAML metadata, not a heavier package-manifest format.
- **Not cryptographically verified on install by default.** `openclaw skills verify @owner/<slug>` can query ClawHub for a `clawhub.skill.verify.v1` "trust envelope," but that's registry/security-scan metadata (VirusTotal, ClawScan, static analysis results), not a signature or hash check of the skill content itself. The docs explicitly say: "Treat third-party skills as **untrusted code**." Independent security research on the ClawHub ecosystem is more blunt: skill installs are "written directly into the workspace directory without a signature check or hash manifest" and "execute with full host-agent privileges... without sandboxing or signature verification" by default (arXiv:2606.01494, "ClawHub Security Signals," and arXiv:2603.27517, "A Security Analysis of the OpenClaw AI Agent Framework" — treat as corroborating community/academic sources, not primary docs, but they agree with the docs' own "untrusted code" framing).
- Actual sandboxing exists but is a **separate, opt-in mechanism scoped to tool execution**, not skill installation: Docker/Podman (local) or SSH/OpenShell (remote) containers, off by default, with restrictive defaults when enabled (`network: none`, `readOnlyRoot: true`, `capDrop: ALL`, non-root). Source: [docs.openclaw.ai/gateway/sandboxing](https://docs.openclaw.ai/gateway/sandboxing).
- **Implication:** if this project needs skill-level supply-chain integrity (signed/verified skills before they can run), OpenClaw does not provide that out of the box — it has to be built or enforced at the operator-policy layer (there is a local install-policy gate mentioned in the docs, not yet independently verified in depth here).

**2. Event subscriptions = "Hooks."** Confirmed real and matches the concept, different name. Hooks are scripts that run inside the Gateway when named events fire: `command:new/reset/stop`, `session:auto-reset`, `session:compact:before/after`, `session:patch`, `agent:bootstrap`, `gateway:startup/shutdown/pre-restart`, `message:received/transcribed/preprocessed/sent` — plus bare family subscriptions (e.g. `message` for all message events). Designed for "operator-managed side effects and command/lifecycle automation," not deep runtime policy control. Source: [docs.openclaw.ai/automation/hooks](https://docs.openclaw.ai/automation/hooks).

**3. "Action loop" → OpenClaw's actual term is "agent loop."** Minor terminology correction. It's a **per-session, serialized** loop: intake → context assembly → model inference → tool execution → streaming → persistence. Scoped to one agent run at a time; the docs contain no mention of orchestration or routing at this layer. Source: [docs.openclaw.ai/concepts/agent-loop](https://docs.openclaw.ai/concepts/agent-loop).

**4. `plugin-sdk` — confirmed scope.** A typed registration API (`OpenClawPluginApi`, imported via scoped subpaths like `openclaw/plugin-sdk/plugin-entry`, `.../channel-core`, `.../core`) for: capability providers (model/text-inference, embeddings, speech, transcription, voice, media generation, web fetch/search), `registerTool()` / `registerCommand()` / `registerNodeHostCommand()`, infrastructure (HTTP routes, Gateway RPC methods, background services, middleware, memory extensions), and workflow participation (session extensions, UI descriptors, tool metadata, next-turn injections, hooks). It also defines `contracts.trustedToolPolicies` — a real, code-level tool-permission gating mechanism worth Security evaluating against §8.3's "enforced in code, not asserted in a prompt" requirement, separately from this pass. Source: [docs.openclaw.ai/plugins/sdk-overview](https://docs.openclaw.ai/plugins/sdk-overview).

**5. Multi-agent / handoff / session / task-queue primitives — the load-bearing question. Mixed result, more nuanced than the prior prediction.**
- **Session/state management: OpenClaw genuinely has this, and it's more solid than the doc's prior framing implied.** Multiple isolated agents can run in one Gateway process, each with its own workspace, state directory, and **SQLite-backed session history**, keyed `agent:<agentId>:<mainKey>`. Source: [docs.openclaw.ai/concepts/multi-agent](https://docs.openclaw.ai/concepts/multi-agent).
- **Routing between agents is channel-binding, not task/domain routing.** "Bindings" map a channel account (a Slack workspace, a WhatsApp number, etc.) to one agent persona, deterministically, most-specific-wins. This answers *which persona owns this conversation*, not *which specialized department should handle this task* — it does **not** give the Fleet Manager's Task Router (`orchestration.md` §4.2) for free.
- **The prior prediction in this doc ("most likely candidate: structured agent-to-agent handoffs... doesn't obviously map") undersells what actually exists — this is the most important correction from this pass.** OpenClaw ships a real async delegation primitive: `sessions_spawn` (non-blocking; a parent agent can spawn a sub-agent run against a specific `agentId`, get a `runId` back immediately, optionally `fork` context) plus `sessions_yield` (wait for the runtime event) and a structured **"announce"** completion payload (source, session ids, type, status, result content, a follow-up instruction, and a stats line with duration/tokens/cost). Sub-agents don't get session/message tools by default. Source: [docs.openclaw.ai/tools/subagents](https://docs.openclaw.ai/tools/subagents). This is a genuine building block for an orchestrator agent delegating to specialized agent personas and getting structured results back — closer to a handoff than the doc assumed, though it's a spawn/wait/announce pattern scoped to one Gateway process, not a peer-to-peer "manager hands off control" pattern like the OpenAI Agents SDK's `handoff`.
- Direct **agent-to-agent messaging** exists via the `openclaw` tool but is **off by default** and must be explicitly enabled and allowlisted.
- **No evidence of a durable, general-purpose task queue** (persistence across Gateway restarts/processes, priority, retry/backoff, dead-lettering) in the docs reviewed. `sessions_spawn`/`sessions_yield` is an in-process async run + event-wait mechanism, not that. This remains **unverified as absent** (a documentation gap isn't proof of non-existence) rather than confirmed-absent — flagged as still open, not resolved.

**Still open / not verified in this pass:** whether `trustedToolPolicies` is sufficient for this project's full Permission Manager needs (Security's call, not Research's); whether a durable cross-process task queue exists anywhere in OpenClaw beyond what's covered above; guardrail hook points for NeMo Guardrails integration (separate research question, not covered here). Don't treat these as resolved by this entry.

What doesn't change with the runtime swap: the Fleet Manager still owns the higher-level responsibilities, independent of what's underneath it.

```
AI FLEET PLATFORM
└── Fleet Manager
    ├── Agent Registry        → runtime-agents.md §3.3
    ├── Task Router            → orchestration.md §4.2
    ├── Workflow Manager       → workflow.md
    ├── Session Manager        → memory.md §6.2.2
    ├── Memory Manager         → memory.md
    ├── Permission Manager     → security-architecture.md
    ├── Usage Manager          → §7.4 below, observability.md
    ├── Observability          → observability.md
    └── Dashboard              → observability.md
         ↓
    OpenClaw Runtime   ← was "OpenAI Agents SDK" in the source spec — see correction above
         ↓
  ┌───────────┼───────────┐
  ↓            ↓            ↓
Research    Product    Engineering
 Agent       Agent        Agent
```

**Fleet layer** (runtime-agnostic — this doesn't change based on what executes underneath): which agents exist, where tasks route, how workflows are managed, how sessions and memory are managed, permissions, usage tracking, observability, dashboard.

**Runtime layer**: OpenClaw provides *some* set of primitives required to actually execute agents. **Update (research pass, 2026-08-18 — see "Verified findings" above for full detail and sources):** the original prediction here — that structured agent-to-agent handoffs were the most likely missing piece — undersold what's actually there. OpenClaw has real per-agent SQLite-backed session/state management and a `sessions_spawn` / `sessions_yield` / "announce" async delegation pattern that functions as a genuine (if in-process, non-durable) handoff primitive. What OpenClaw does *not* give the Fleet Manager for free is **task/domain-based routing** (its own "multi-agent routing" is channel-binding — which persona owns a conversation — not which specialized department should own a task) and **any durable, cross-process task queue** (persistence across restarts, priority, retry/backoff, dead-lettering) — the latter is unverified-as-absent, not confirmed-absent, and should be re-checked before the Task Router (`orchestration.md` §4.2) is designed around an assumption either way. Those two remain the open implementation questions for `architecture-review` to resolve, not the handoff mechanics originally flagged here.

## 7.2 Model Routing

Policy-driven selection of an appropriate LLM per task, based on complexity, latency, cost, and required accuracy. Don't use one expensive, high-capability model for every task regardless of what the task actually needs.

| Task type | Model tier |
|---|---|
| Simple classification | Lower-cost model |
| Research | Research/reasoning-capable model |
| Complex architecture | High-capability model |
| Code generation | Coding-capable model |
| Summarization | Efficient model |

```
Task
  ↓
Model Policy
  ↓
Evaluate Requirements
  ├── Complexity
  ├── Latency Requirement
  ├── Cost Budget
  └── Accuracy Requirement
  ↓
Selected Model
  ↓
Agent Execution
```

The point: never hard-code `EVERY TASK → SAME MODEL`. This is exactly the reasoning already applied to this project's own dev-loop agents — `architect`/`security` on the high-capability tier, `researcher`/`implementer`/`reviewer` on the cost-efficient tier — same policy, applied one level up to the runtime fleet itself.

## 7.3 Model Policy

Model selection weighs multiple factors together, not any single one in isolation:

```
                TASK
                  ↓
            MODEL POLICY
     ┌───────────┼───────────┐
 Complexity     Cost       Latency
     └───────────┼───────────┘
                  ↓
           Model Selection
```

A high-complexity task with a strict accuracy requirement can justify a more capable (and more expensive) model. A simple task with a tight cost or latency budget should use a more efficient one. This makes model selection a **platform policy**, not something each agent decides for itself — the same principle as deterministic task routing (`orchestration.md` §4.2): intelligence informs the decision, application logic enforces it.

## 7.4 Token Management

Every LLM call is tracked — who used the model, how many tokens, how long it took, how much it cost. Token usage is a first-class subsystem, not an afterthought bolted on for billing.

Every LLM call records:

| Field | | Field |
|---|---|---|
| Agent ID | | Cached Tokens |
| Task ID | | Estimated Cost |
| Session ID | | Latency |
| Model | | Timestamp |
| Provider | | |
| Input Tokens | | |
| Output Tokens | | |

```
                Token Usage
                    │
     ┌──────────────┼──────────────┐
   Agent           Task         Workflow
     │               │               │
   Cost            Cost            Cost
```

The platform calculates: cost per task, per agent, per department, per model, per user, per workflow, and daily/weekly/monthly cost. This matters more, not less, as the fleet grows — a cost leak that's negligible at low volume compounds fast at scale. Full detail on how this feeds the dashboard and alerting lives in `observability.md`.

## How Runtime, Model Routing, and Tokens Connect

```
TASK
  ↓
Executive Orchestrator
  ↓
Task Router
  ↓
Assigned Agent
  ↓
Model Policy
  ↓
Selected Model
  ↓
OpenClaw Agent Runtime   ← was "OpenAI Agent Runtime" — see §7.1 correction
  ↓
Agent Execution
  ↓
  ┌─────────────┴─────────────┐
Token Usage              Execution Data
  ↓                             ↓
Cost Tracking             Observability
```