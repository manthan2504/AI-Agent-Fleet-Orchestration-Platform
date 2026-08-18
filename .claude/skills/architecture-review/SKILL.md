---
name: architecture-review
description: Use when evaluating system design, deciding whether to add/remove/combine a component, comparing architectural alternatives, or reviewing an implemented system against its intended design. Trigger phrases include "architecture review", "should we add", "does this fit our design", "how should this be structured", "is this over-engineered".
allowed-tools: Read, Grep, Glob, WebSearch, WebFetch
---

# Architecture Review

A structured process for evaluating how a system's parts fit together — not a free-form design discussion.

## Process

1. **Establish context** — objective, consumers, major workflows, functional and non-functional requirements, constraints, current implementation state.
2. **Map the current system** — components, data flow, control flow, dependencies, state, external services, execution boundaries. Inspect the actual code and docs; don't reason from a diagram alone.
3. **Find the problems** — tight coupling, circular dependencies, unclear ownership, duplicated responsibility, excessive abstraction, single points of failure, scaling limits, security-boundary gaps, observability gaps, hard-to-test components, unneeded infrastructure.
4. **Evaluate real alternatives** — correctness, simplicity, performance, scalability, reliability, security, maintainability, operational burden, cost, ecosystem maturity. Compare on merits, not novelty. If a technology or capability claim is uncertain, use the `research` skill to verify it rather than assuming.
5. **Recommend** — what stays, changes, gets removed, gets added, why, the trade-offs, migration implications, confidence.

For every significant component: state its responsibility, inputs, outputs, dependencies, state ownership, permissions/authority, and failure behavior. If you can't state these cleanly, that's a finding in itself.

## Guardrails on the process

- Every proposed component needs a stated problem it solves, why an existing component can't solve it, and what it costs to add. No component "because it's common in this kind of system."
- Existing design is a proposal, not a fixed spec — including this project's own architecture doc. Challenge it when the evidence warrants; don't defend it out of inertia or discard it without a concrete reason.
- Don't optimize for hypothetical future scale that isn't an actual stated requirement.

## Output format

**Objective** — the architectural question being answered.
**Current Understanding** — the relevant existing design, summarized.
**Problems / Risks** — concrete issues, not vague concerns.
**Options** — for each real alternative: approach, advantages, disadvantages, implications.
**Recommended Direction** — the call, stated plainly.
**Proposed Structure** — component relationships as a concise hierarchy or diagram, when it clarifies more than it costs.
**Trade-offs** — what the recommendation sacrifices or complicates.
**Implementation Impact** — which components, interfaces, data flows, or files are affected.
**Confidence** — High / Medium / Low, and why.
**Open Questions** — what's unresolved and what would resolve it.
