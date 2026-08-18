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

**Human and agent identities are not the same kind of principal, and that distinction has to survive into whatever authentication mechanism actually gets built.** §8.7.1's `ApprovalRequest.designated_approver` can only be resolved by a human-held credential — a security review specifically flagged that an implementation using one uniform token scheme for both agents and humans would satisfy this section's "authorization applies to agents too" framing while making self-approval or approver-shopping possible in practice. Whoever designs the concrete auth mechanism needs both this section and §8.7.1 open at the same time, not just this one.

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

The actual matrix, for the six Phase-1-scoped agents (`runtime-agents.md`'s "Current Phase Scope") — an initial, illustrative allocation grounded in what's already described piecemeal elsewhere in this project (the Market Research Agent's tool set in `runtime-agents.md` §3.1/§3.2, the Research-Agent/Production-DB example above), meant to be refined as real tooling is built, not treated as permanently final. A security review of the first version of this matrix (2026-08-18) found that a single undifferentiated "Filesystem" column understated risk — filesystem write access over a repo working tree or a Git hook is functionally equivalent to Git write, so it's now split read/write like Git is:

| Agent | Web Search | Browser | Knowledge/Doc Store (read) | Doc Store (write) | Git (read) | Git (write) | Filesystem (read) | Filesystem (write) | Database (read) | Database (write) | Cloud/Infra deploy |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Executive Orchestrator | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Research | ✓ | ✓ | ✓ | ✓ (research reports only) | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Product | ✓ | ✓ | ✓ | ✓ (product specs only) | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| Engineering | ✓ | ✓ | ✓ | ✓ (technical docs) | ✓ | ✓ | ✓ | ✓ | ✓ (scoped¹) | ⚠ approval required | ⚠ approval required |
| QA | ✗ | ✓ | ✓ | ✓ (test reports) | ✓ | ✗ | ✓ | ✗ | ✓ (scoped¹, test data only) | ✗ | ✗ |
| Security | ✓ | ✗ | ✓ | ✓ (findings/reports only — see rationale) | ✓ | ✗ | ✓ | ✗ | ✓ (scoped¹) | ✗ | ✗ |

`✓` = granted by default · `✗` = never granted to this role · `⚠` = requires the Human Approval gate (§8.7) every time, regardless of role — no agent gets deploy or destructive-DB access unconditionally, per this project's own non-negotiables. ¹ "scoped" means narrowed via `Permission.resource_scope` (§8.3.2) — e.g. non-production schemas only, never the production database the Research-Agent example above is warning about; an unscoped `Database (read)` grant would defeat that example's whole point.

Rationale for the shape, not just the values: the Executive Orchestrator coordinates rather than performs (`orchestration.md` §4.1), so it gets read access to shared knowledge for classification but no execution tools of its own — those belong to the agent it dispatches to. Research/Product are read-heavy with a narrow, department-scoped write. Engineering and QA both touch code, but only Engineering writes it; QA reads and runs it without committing, which is exactly why QA's Filesystem grant stops at read — a QA agent with filesystem *write* could modify the code it's supposed to be independently testing, defeating the "doesn't commit" boundary as surely as Git write would. Security gets broad read access for audit (mirroring this project's own `security` dev-loop agent, which audits and never fixes) with one narrow, explicit exception: it can write its own findings/reports, and nothing else — not "no write access anywhere," which the matrix's Doc Store cell would otherwise contradict.

**Per-cell grants don't compose safely — this matrix can't show that on its own.** Research/Product hold Web Search + Browser (attacker-reachable external content) and Doc Store write; Engineering reads the Doc Store and holds Git write. A malicious or manipulated web page can ride through a research report into Engineering's context and out through a commit — every individual cell above is still correctly scoped, but the chain isn't something a per-agent table can catch. That has to be a workflow-level control (content provenance/tagging as it crosses the Research → Engineering boundary in `orchestration.md` §4.7's collaboration-request path, or an execution guardrail per §8.5's rail types) — flagging this as a real gap the matrix format has, not resolving it here.

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
| `approval_config` | object (title, description, severity, timeout, `designated_approver`) | required if `decision = REQUIRE_APPROVAL` | Feeds the `ApprovalRequest` created when this policy fires (§8.7.1) — including `designated_approver`, sourced here for the same reason `risk_level` is: a security review pointed out that pinning `risk_level` to server-side config while leaving `designated_approver` unsourced just moves the same self-approval risk onto a different field |

**Evaluation order and default, stated explicitly (a security review flagged both as missing — an unstated precedence or default is itself a bypass, since whatever an implementer happens to build becomes the real policy):**
- **Most-specific-wins, with one absolute floor.** A row with a matching `tool_id` takes precedence over a role-wide row (`tool_id` omitted) for the same `agent_role` — *except* for the six action classes `security-architecture.md` §8.7 and CLAUDE.md's non-negotiables name (production deploy, destructive DB operation, credential rotation, infrastructure destruction, financial transaction, external communication). For those, `REQUIRE_APPROVAL` is a floor no row at any specificity may resolve below — a hand-authored, tool-specific `(Engineering, azure.deploy, ALLOW)` row is invalid configuration and must be rejected at write time, not treated as a legitimate override. A second security pass on the first version of this rule found that "specificity wins" alone would have let exactly that row exist, silently defeating a project non-negotiable while every *stated* rule was followed — this floor is what closes that. Two rows with the same specificity for the same role/tool pair is likewise a write-time-rejected configuration error.
- **Most-restrictive-wins is deliberately not the general rule outside that floor** — specificity is. A tool-specific `ALLOW` legitimately overrides a role-wide `REQUIRE_APPROVAL` for anything *not* in the six-class floor above, e.g. an otherwise-gated role explicitly cleared for one specific low-risk tool. What must never happen, in either direction: a role-wide row silently shadowing a tool-specific one (loses to specificity), or any row shadowing the six-class floor (loses to the floor, full stop).
- **Default is `DENY`.** If no `ToolPolicy` row matches an `(agent_role, tool_id)` pair at all, the Gateway denies the call. This project already commits to this posture generally (§8.3's whole point); it has to be written down for this specific entity too, not just implied.
- **The Tool Permission Matrix (§8.3.1) is the source that compiles into `ToolPolicy` rows**, not a parallel description of the same thing maintained by hand. Compilation is category-scoped: a matrix cell like "Cloud/Infra deploy" or "Database (write)" compiles into a row covering *every* `tool_id` classified under that category — a member tool cannot be "more specific" than its own category in a way that escapes the floor above, because the category-level row and the floor are the same compilation step, not two things that could disagree. `Agent.Tools` (`runtime-agents.md`'s registry field) is validated against the compiled policy at agent registration, not treated as an independent grant — if `Agent.Tools` lists something the matrix doesn't grant that role, registration fails closed (rejected), it does not silently widen access to match the declared list. This is what makes `runtime-agents.md`'s claim that tools are "enforced via the Tool Permission Matrix, not just declared here" actually true rather than aspirational.

> **OpenClaw grounding note, not a final decision.** If `ToolPolicy` enforcement is ever implemented against OpenClaw's `plugin-sdk` rather than a fully independent Tool Gateway, ground the `REQUIRE_APPROVAL` path on OpenClaw's documented `before_tool_call` hook's `requireApproval` field (confirmed, typed, available to any plugin) — not on `contracts.trustedToolPolicies` (its approval-outcome support is unconfirmed, and one third-party plugin's real-world experience contradicts the docs on whether it's even available to non-bundled plugins). Full detail: `.claude/agent-memory/researcher/openclaw_trusted_tool_policies.md`. Two things that note undersold, per a subsequent security review of it: (1) `requireApproval.allowedDecisions` can include `"allow-always"` — one human click converts a "every time" gate into a standing grant, so if this path is used, `allowedDecisions` must be constrained to exclude `allow-always` for anything this matrix marks `⚠`, not left at whatever OpenClaw's default offers; (2) `onResolution` fires on `"cancelled"` as well as `"timeout"` — the fail-closed handling described in §8.7.1 has to cover both, not just the timeout case. And structurally: an independent Tool Gateway (§8.6) — outside the agent's own runtime process — should be the default design, with an in-process `before_tool_call` hook treated as a constrained fallback if the independent gateway isn't available, not as an equal alternative; a control living inside the same process it governs is a weaker boundary than one outside it. **That fallback has a hard precondition, not just a general preference:** it must never be the sole enforcement for a role that also holds `Filesystem (write)` (§8.3.1 — currently Engineering). §8.3.1's own rationale establishes that filesystem write over a repo tree or a Git hook is functionally equivalent to code execution — for such a role, an in-process hook isn't a weaker boundary than an independent gateway, it's no boundary at all, since the agent it's meant to constrain can plausibly alter the process enforcing it. Roles with filesystem write must be gated by the independent Tool Gateway, full stop; the in-process fallback is only acceptable for roles without that access. This is still a technical grounding note for whoever implements the gateway, not a decision made here.

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
Engineering Agent → "Deploy to Production" → Risk Evaluation → ⚠ Human Approval Required
                                                                  ↓
                                                               Manager
                                                            ┌────┴────┐
                                                         Approve   Reject
                                                            ↓
                                                        Execution
```

(This example uses the Engineering Agent, matching §8.3.1's matrix — deploy is one of the two `⚠` cells assigned to Engineering, not DevOps, which is future scope per `runtime-agents.md`'s Current Phase Scope.)

If rejected, the action doesn't execute — full stop, no fallback path. The agent can propose an action, but a human retains explicit authorization authority over anything potentially damaging or sensitive. See `workflow.md` §5.8 for where this sits inside workflow execution specifically.

### 8.7.1 `ApprovalRequest` — entity reference

A security review (2026-08-18) found the first version of this entity granted approval to a free-text description rather than to a specific, checkable tool call, and left the human/agent principal boundary unstated. Both fixed below, plus the other findings from that pass.

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Unique identifier |
| `task_id` | string | yes | The task whose execution is paused pending this decision (moves the task to `PENDING_APPROVAL`, `orchestration.md` §4.4.2) |
| `tool_call_id` | string | yes | The specific tool invocation this approval covers — **not** the whole task. A task that raises two gated calls gets two `ApprovalRequest`s; approving one never resumes the other. |
| `tool_id` | string | yes | Which tool `tool_call_id` is calling — lets the approver (and the Gateway, on resolution) verify this request matches an actual `ToolPolicy` row marked `REQUIRE_APPROVAL` (§8.3.2), rather than trusting `action`'s prose alone |
| `params_snapshot` | object or hash of the tool call's parameters, captured at request time | yes | What the human is actually approving. The Gateway must re-check the live call's parameters against this snapshot at execution time and re-request approval on any mismatch — a hook or policy that rewrites params after approval was granted must not silently execute against different arguments than what was shown to the human. **The comparison covers only the agent-supplied parameters** — it explicitly excludes whatever the Tool Gateway injects at execution time per §8.8 (credentials, tokens). Those are expected to differ from the snapshot by design; comparing them would make every gated call mismatch on the credential alone and livelock on endless re-approval. The Gateway enumerates which fields are its own injections before running this check, not left for an implementer to infer. |
| `requested_by` | agent instance ID | yes | Which agent's tool request triggered this |
| `action` | string | yes | A human-readable label (e.g. "Deploy to Production") — describes `tool_id`/`params_snapshot` for the approver's benefit, is not itself the thing being authorized, and must not be the only field an approval UI renders |
| `risk_level` | enum: `info`, `warning`, `critical` | yes | Set from the matching `ToolPolicy.approval_config` (§8.3.2) — **never** agent-supplied. An agent proposing its own risk level for the action it's requesting is the approval gate auditing itself. |
| `status` | enum: `PENDING`, `APPROVED`, `REJECTED`, `TIMED_OUT` | yes | Current disposition. Immutable once non-`PENDING` — no path, API or otherwise, may transition a resolved request to a different resolved status (see `api.md` §11.7's `409` behavior, which is the API-layer expression of this same invariant, not the only place it holds) |
| `requested_at` / `resolved_at` | timestamp | `resolved_at` only once resolved | When raised / when a human acted on it |
| `designated_approver` | user ID or role (e.g. "any user with the `approver` role for this department") | yes | Who is authorized to resolve this specific request. Without this, "the caller isn't the designated approver" (`api.md` §11.7) has nothing to check against, and it becomes possible for the same credential that submitted the task to also approve it. `designated_approver` must never resolve to `requested_by`'s owning principal, and the credential that resolves an approval must be a human-held principal, distinct in kind from the agent-execution tokens used elsewhere on this API — this project's non-negotiable that high-risk actions need human approval, not just an approval-shaped API call, otherwise isn't actually enforced. |
| `resolved_by` | user ID | only once resolved | Which human approved or rejected it — must equal `designated_approver` (or be a member of it, if a role) |
| `reason` | string | no | Optional human-supplied rationale, especially useful on rejection |
| `timeout_ms` | number | **yes**, with a platform-wide default (e.g. 24h) if the requesting `ToolPolicy` doesn't set one | If no human response arrives in time, `status` becomes `TIMED_OUT` and the request is treated as a rejection (fail closed, not fail open) — the task named in `task_id` moves to `FAILED` with a `Policy rejection` error, then straight to `DEAD_LETTERED` (`orchestration.md` §4.4.2/§4.6), the same as an explicit `REJECTED`. Making this optional-with-no-default was itself a gap: an approval created without a timeout parks its task in `PENDING_APPROVAL` indefinitely, and enough of those can exhaust a department's whole concurrency budget (`orchestration.md` §4.5) — a fail-closed control has to fail closed on *time* as well as on outcome. |

**On the `event.approval_timed_out` audit gap:** `observability.md`'s event catalog lists `approval.requested`/`approved`/`rejected` but not a timeout event — add `approval.timed_out` there too, since the fail-closed timeout path is exactly the one that most needs to be independently observable (nobody explicitly acted, so there's no human-initiated log entry to fall back on otherwise).

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