# Vetted Sources — AI Agent Fleet Project

A running catalog of sources already checked and trusted for this project's specific stack. Check here before searching from scratch. Add to this file when research turns up something worth trusting again — don't let it go stale by only ever reading it, never writing to it.

Each entry: what it's authoritative for, and the date it was last confirmed current. Fast-moving entries (runtime/SDK specifics) need periodic re-confirmation, not a one-time check.

## Agent runtime — OpenClaw

- Official docs — runtime architecture, plugin-sdk, skill manifest format, sandboxing model.
  _Confirm before relying on: session/state handling, agent-to-agent handoff mechanics, guardrail hook points — these are the specific gaps flagged in the architecture spec's original OpenAI Agents SDK assumptions that need re-verification against OpenClaw's actual primitives._

## Security / guardrails — NVIDIA NeMo Guardrails

- Official docs — rail types (input/retrieval/execution/output), OpenTelemetry integration, configuration.

## Observability

- OpenTelemetry official docs — tracing/metrics standard this project has adopted.

## Add new entries here

```
## <Topic>
- <Source> — <what it's authoritative for>.
  _Last confirmed: <date>. Re-check if: <condition, e.g. "before a major version bump" or "if >3 months old">._
```
