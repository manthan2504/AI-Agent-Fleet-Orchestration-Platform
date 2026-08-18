# Security & Governance

Security in an AI Agent Fleet cannot depend only on the model's instructions. The security architecture protects the fleet through multiple layers — authentication, authorization, data/tool permissions, guardrails, secret management — with NeMo Guardrails serving as *a* policy and safety layer, not the complete security system.

**Core principle:** the agent may request an action; the platform decides whether that action is permitted. A request is not an authorization.

## 8.1 Security Architecture

The basic flow a request travels through:

```
User
  ↓
Fleet Gateway
  ↓
Authentication / Authorization
  ↓
NeMo Guardrails
  ↓
Agent Orchestrator
  ↓
Agent
  ↓
Tool Gateway
  ↓
External Systems
```

What each layer actually does:

| Layer | Answers |
|---|---|
| **Authentication** | Who is allowed to access the fleet at all? |
| **Authorization** | What is this user or agent specifically allowed to do? A Research Agent shouldn't automatically be able to modify engineering systems. |
| **Tool Permissions** | Which tools can each agent use? (Research Agent → Web Search ✓, Production Database ✗) |
| **Data Permissions** | What information can an agent access? Only what it's authorized to see. |
| **Execution Guardrails** | Which tool/model actions are allowed, checked before/during execution? |
| **Output Guardrails** | What's allowed to leave the system? Prevents restricted information surfacing in a final response. |
| **Secret Management** | Credentials never live directly in prompts, memory, logs, or source code — managed separately. |

> **How this connects to OpenClaw.** `runtime.md` §7.1's verified findings (2026-08-18) correct an earlier assumption here: OpenClaw skills are **not** WASM-sandboxed or cryptographically verified on install by default — they're `SKILL.md` prompt-injected instruction packs, explicitly documented as "untrusted code." Real sandboxing exists but is a separate, opt-in, tool-execution-scoped mechanism (Docker/Podman/SSH containers), not a skill-install-time guarantee. Practically: don't lean on OpenClaw's skill system for supply-chain integrity or execution isolation — that has to be enforced at this project's own policy layer (Tool Gateway, §8.6) or the operator-side sandboxing config, not assumed from the runtime. NeMo Guardrails and OpenClaw's sandboxing remain complementary, not substitutes for each other, but neither substitutes for the layers in this document either.

## 8.2 Authentication & Authorization

Related, but answering different questions.

**Authentication** — *who are you?*

```
User → Authentication → Verified Identity
```

**Authorization** — *what are you allowed to do?*

```
Verified User → Authorization → Allowed Operations
```

The same principle applies to agents, not just human users. An Engineering Agent and a Research Agent both exist in the fleet, but they don't get the same permissions by default.

## 8.3 Tool Permissions

Agents don't automatically get access to every tool.

```
Research Agent → Web Search ✓
Research Agent → Production Database ✗
```

```
              Tools
                │
    ┌───────────┼───────────┐
   Web          Git        Azure
    │            │            │
Research       Eng         DevOps
```

The **Tool Permission Matrix** defines which tools and resources each agent can access — and the application/tool gateway *enforces* it, not the model's instructions.

**This is the point that matters most in this whole section:** tool access must be enforced by the application/tool layer. This is not sufficient:

```
System Prompt: "You are not allowed to deploy."
```

A system prompt is a request to the model, not a control. The actual Tool Gateway (§8.6) has to prevent unauthorized deployment regardless of what the prompt says.

> **This project already enforces this principle**, one layer down: `implementer.md`, `reviewer.md`, and `security.md` each have a `PreToolUse` hook (`scripts/validate-safe-bash.sh`) that blocks destructive/production commands at the tool-execution layer — not just an instruction in the agent's prompt saying not to run them. Same principle, already running, not just described.

### 8.3.1 Tool Permission Matrix

The actual matrix, for the six Phase-1-scoped agents (`runtime-agents.md`'s "Current Phase Scope") — an initial, illustrative allocation grounded in what's already described piecemeal elsewhere in this project (the Market Research Agent's tool set in `runtime-agents.md` §3.1/§3.2, the Research-Agent/Production-DB example above), meant to be refined as real tooling is built, not treated as permanently final:

| Agent | Web Search | Browser | Knowledge/Doc Store (read) | Doc Store (write) | Git (read) | Git (write) | Filesystem | Database (read) | Database (write) | Cloud/Infra deploy |
|---|---|---|---|---|---|---|---|---|---|---|
| Executive Orchestrator | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Research | ✓ | ✓ | ✓ | ✓ (research reports only) | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Product | ✓ | ✓ | ✓ | ✓ (product specs only) | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Engineering | ✓ | ✓ | ✓ | ✓ (technical docs) | ✓ | ✓ | ✓ | ✓ | ⚠ approval required | ⚠ approval required |
| QA | ✗ | ✓ | ✓ | ✓ (test reports) | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ |
| Security | ✓ | ✗ | ✓ | ✓ (findings/reports) | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ |

`✓` = granted by default · `✗` = never granted to this role · `⚠` = requires the Human Approval gate (§8.7) every time, regardless of role — no agent gets deploy or destructive-DB access unconditionally, per this project's own non-negotiables.

Rationale for the shape, not just the values: the Executive Orchestrator coordinates rather than performs (`orchestration.md` §4.1), so it gets read access to shared knowledge for classification but no execution tools of its own — those belong to the agent it dispatches to. Research/Product are read-heavy with a narrow, department-scoped write. Engineering and QA both touch code, but only Engineering writes it; QA reads and runs it without committing. Security gets broad read access for audit (mirroring this project's own `security` dev-loop agent, which audits and never fixes) and no write access anywhere.

### 8.3.2 `Permission` and `ToolPolicy` — entity reference

`Permission` (a data-access grant, distinct from tool access):

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Unique identifier |
| `grantee` | agent role or agent instance ID | yes | Who this grant applies to |
| `resource_type` | enum: `Knowledge`, `DocumentStore`, `Database`, `Filesystem`, `Git`, `Infrastructure` | yes | What kind of resource |
| `scope` | enum: `READ`, `WRITE` | yes | What operation is allowed |
| `resource_scope` | string (e.g. a department, a document category) | no | Narrows the grant below the resource type, matching the "research reports only" / "product specs only" style narrowing used in the matrix above |

`ToolPolicy` (a tool-execution decision, evaluated by the Tool Gateway, §8.6, before a tool call runs):

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Unique identifier |
| `agent_role` | string | yes | Which agent role this policy applies to |
| `tool_id` | string (or omitted to match all tools for this role) | no | Which tool this governs |
| `decision` | enum: `ALLOW`, `DENY`, `REQUIRE_APPROVAL` | yes | The gate's decision for this tool/role pair |
| `approval_config` | object (title, description, severity, timeout) | required if `decision = REQUIRE_APPROVAL` | Feeds the `ApprovalRequest` created when this policy fires (§8.7.1) |

> **OpenClaw grounding note, not a final decision.** If `ToolPolicy` enforcement is ever implemented against OpenClaw's `plugin-sdk` rather than a fully independent Tool Gateway, ground the `REQUIRE_APPROVAL` path on OpenClaw's documented `before_tool_call` hook's `requireApproval` field (confirmed, typed, available to any plugin) — not on `contracts.trustedToolPolicies` (its approval-outcome support is unconfirmed, and one third-party plugin's real-world experience contradicts the docs on whether it's even available to non-bundled plugins). Full detail: `.claude/agent-memory/researcher/openclaw_trusted_tool_policies.md`. This is a technical grounding note for whoever implements the gateway, not a decision made here.

## 8.4 Data Permissions

Tool permissions control what an agent can *do*. Data permissions control what an agent can *see*.

```
Research Agent → Knowledge Retrieval → Permission Check → Authorized Research Information
```

An agent retrieves only what it's authorized to access. This matters more because of shared organizational memory (`memory.md` §6.2.4) — shared knowledge does not mean unrestricted knowledge. Permissions still apply on every retrieval, not just at the door.

## 8.5 NeMo Guardrails

Positioned as a policy and safety layer, **not** the complete security architecture. It provides configurable controls around LLM interactions, tools, retrieval, and outputs — it does not replace authentication, authorization, permissions, or secret management.

```
                Security Architecture
     ┌────────────────┼────────────────┐
Authentication    Authorization    Permissions
                        │
                 NeMo Guardrails
                        │
                 Agent Execution
```

The reference architecture describes different rail types, each evaluating the interaction at a different point in the execution flow:

| Rail | Evaluates |
|---|---|
| Input rails | What comes into the model |
| Retrieval rails | What gets pulled from knowledge/memory |
| Execution rails | What the model is about to do (tool calls, actions) |
| Output rails | What the model is about to return |

**The distinction that matters:** think of it as `NeMo Guardrails = policy/safety enforcement layer`, never as `NeMo Guardrails = entire security system`. Authentication, authorization, tool permissions, data permissions, secret management, and general application security all still have to exist independently of it.

## 8.6 Tool Gateway

A controlled interface between agents and external tools/infrastructure — enforces permissions, validation, security, approvals, rate limits, secrets handling, logging, and auditing before any tool actually executes.

Agents don't directly touch infrastructure or external systems:

```
Agent
  ↓
Tool Gateway
  ├── Git
  ├── Azure
  ├── Cloud
  ├── Database
  ├── Browser
  ├── Filesystem
  └── APIs
```

The Tool Gateway enforces authentication, authorization, rate limits, validation, logging, approval requirements, secret injection, and audit trails. When an agent wants to perform an external action:

```
Agent → Tool Request → Tool Gateway → Permission/Policy Checks → External System
```

The agent never directly controls the external system — the gateway is always in the path.

## 8.7 Human Approval

Some operations are too sensitive to execute automatically: production deployment, database deletion, financial transactions, credential rotation, infrastructure destruction, external communication.

```
Agent → Tool Request → Risk Evaluation → Human Approval Required
                                             ├── Approved → Execute
                                             └── Rejected → Stop
```

**Example:**

```
DevOps Agent → "Deploy to Production" → Risk Evaluation → ⚠ Human Approval Required
                                                                  ↓
                                                               Manager
                                                            ┌────┴────┐
                                                         Approve   Reject
                                                            ↓
                                                        Execution
```

If rejected, the action doesn't execute — full stop, no fallback path. The agent can propose an action, but a human retains explicit authorization authority over anything potentially damaging or sensitive. See `workflow.md` §5.8 for where this sits inside workflow execution specifically.

### 8.7.1 `ApprovalRequest` — entity reference

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Unique identifier |
| `task_id` | string | yes | The task whose execution is paused pending this decision (moves the task to `PENDING_APPROVAL`, `orchestration.md` §4.4.2) |
| `requested_by` | agent instance ID | yes | Which agent's tool request triggered this |
| `action` | string | yes | The specific action awaiting approval (e.g. "Deploy to Production") |
| `risk_level` | enum: `info`, `warning`, `critical` | yes | Drives how the request is surfaced (dashboard urgency, notification) |
| `status` | enum: `PENDING`, `APPROVED`, `REJECTED`, `TIMED_OUT` | yes | Current disposition |
| `requested_at` / `resolved_at` | timestamp | `resolved_at` only once resolved | When raised / when a human acted on it |
| `resolved_by` | user ID | only once resolved | Which human approved or rejected it |
| `reason` | string | no | Optional human-supplied rationale, especially useful on rejection |
| `timeout_ms` | number | no | If set and no human response arrives in time, `status` becomes `TIMED_OUT` and the request is treated as a rejection (fail closed, not fail open) |

## 8.8 Secret Management

Secrets are handled separately from agent context entirely — never placed directly inside prompts, memory, logs, or source code.

Not this:

```
Agent Prompt → "Here is the Azure password..."
```

Instead:

```
Agent → Tool Request → Tool Gateway → Secret Management → External System
```

The agent doesn't need to know or retain the underlying credential to perform an authorized operation — it requests the action, the gateway injects the credential at execution time. This also cuts the risk of a secret ever surfacing in a log, a prompt, memory, or a model's output.

> Same rule already lives in `.claude/rules/coding.md` and as a hard boundary in every dev-loop agent (`implementer.md`, `reviewer.md`, `security.md`) — no hardcoded secrets, ever, referenced via environment variable or an existing secrets mechanism instead. This section is the platform-level version of a rule this project already enforces at the build layer.