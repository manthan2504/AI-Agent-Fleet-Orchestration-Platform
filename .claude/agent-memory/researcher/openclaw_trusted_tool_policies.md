---
name: openclaw-trusted-tool-policies
description: Concrete shape/semantics of OpenClaw plugin-sdk's contracts.trustedToolPolicies / registerTrustedToolPolicy — for Permission Manager / ToolPolicy schema design.
metadata:
  type: project
---

Verified 2026-08-18 (follow-up to [[openclaw-primitives]], which had punted this exact question) against docs.openclaw.ai (plugins/manifest, plugins/sdk-overview, plugins/hooks, plugins/plugin-permission-requests, cli/policy) plus one community source (github.com/clawnify/agent-permissions).

**Shape:** `contracts.trustedToolPolicies` is `string[]` (plugin-local policy ids) in the plugin manifest — just a declaration gate. The actual logic is a function registered via `api.registerTrustedToolPolicy(...)`, with an optional `matcher` (canonical tool-id list, omit = match-all). Docs describe its capability narrowly: "can block or rewrite tool params" — no explicit TS interface found for its return type in docs or via (unauthenticated) GitHub code search.

**Compare/contrast with `before_tool_call` hooks (documented, full type found):**
```typescript
type BeforeToolCallResult = {
  params?: Record<string, unknown>;
  block?: boolean;
  blockReason?: string;
  requireApproval?: {
    title: string; description: string;
    severity?: "info" | "warning" | "critical";
    timeoutMs?: number;
    allowedDecisions?: Array<"allow-once" | "allow-always" | "deny">;
    pluginId?: string;
    onResolution?: (decision: "allow-once"|"allow-always"|"deny"|"timeout"|"cancelled") => Promise<void> | void;
  };
};
```
Trusted policies run *before* ordinary `before_tool_call` hooks, host-trusted, evaluated per matched tool call (global to the Gateway process, not a first-class per-agent/per-session scope — that would have to be hand-coded via `ctx.agentId` etc.). **Unconfirmed whether trusted policies support `requireApproval`** — docs never mention it for this tier, only for the ordinary `before_tool_call`/plugin-approval flow. Treat "trusted policies = block/rewrite only, no approval outcome" as the likely-but-unconfirmed reading.

**Runtime configurability:** fixed at plugin registration/manifest declaration ("undeclared ids are rejected before registration"). No documented hot-reload or DB-backed reconfiguration. A separate, unrelated system exists — static `policy.jsonc` conformance layer (`tools.denyTools`, per-agent overlays, checked via `doctor --lint`) — don't conflate with `trustedToolPolicies`.

**Real unresolved discrepancy:** OpenClaw's own docs say installed (non-bundled) plugins *can* register trusted policies if declared + explicitly enabled. A working third-party plugin (`clawnify/agent-permissions`) states from practical experience that `registerTrustedToolPolicy` is "bundled-only; external plugins can't use it" and built its whole permission/approval engine on `before_tool_call` instead specifically to route around this. Not resolved by available primary sources — flagged, not picked.

**Recommendation for ToolPolicy schema design:** don't build the Permission Manager's approval-outcome or external-override needs on `trustedToolPolicies` — build on the `before_tool_call` + `requireApproval` tier instead (confirmed capability, confirmed available to any plugin). Get an authenticated GitHub code-search or maintainer confirmation before finalizing, since the bundled-only question is still open.

**Confidence:** Medium overall — High on manifest shape and `before_tool_call`'s type (verbatim, cross-checked across pages); Low-Medium on trusted-policy approval support and the bundled-only contradiction (genuine doc gap/conflict, not resolved).

**Re-check condition:** before Security/architect finalize the Permission Manager's tool-gating design, and if this memory is more than ~2-3 months old.
