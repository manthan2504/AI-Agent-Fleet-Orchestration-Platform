# Architecture Principles

Standing rules for this project, regardless of which agent or task is active.

- **Task ownership is explicit.** Every task has one owning department/agent. Don't let work drift to whichever agent happens to be handling it.
- **Shared knowledge, isolated context.** Agents can retrieve relevant organizational knowledge on demand; they don't get the full conversation history, every document, or another task's working context by default. If something needs more context than its stated scope, that's worth flagging, not silently granting.
- **Existing architecture is a proposal, not a spec.** This project's own architecture doc — including its choice of OpenClaw as the agent runtime — is the current baseline, open to revision with evidence. Don't defend it out of inertia; don't discard it without a concrete reason.
- **OpenClaw, not the OpenAI Agents SDK.** The runtime is a self-hosted, model-agnostic automation framework (skills, event subscriptions, an action loop, its own plugin-sdk) — not a manager/handoff multi-agent library. Don't assume SDK-style primitives (sessions, runners, built-in handoffs) exist unless verified against OpenClaw's actual API.
- **High-risk actions need human approval, always**: production deployment, destructive database operations, credential rotation, infrastructure destruction, financial transactions, external communications sent on the project's behalf. No task urgency or confidence level overrides this.
- **Tool permissions are enforced in code**, not asserted in a prompt. "You are not allowed to deploy" in a system prompt is not a control.
- **No component without a stated reason.** For anything new: what problem it solves, why an existing piece can't solve it, what it costs to add.
