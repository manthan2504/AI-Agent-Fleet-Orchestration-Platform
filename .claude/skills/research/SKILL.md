---
name: research
description: Use when investigating a technical or architectural question, validating a claim made in project documentation, comparing frameworks/libraries/approaches, or verifying an external technical detail before it's relied on in a design or implementation decision. Trigger phrases include "research this", "compare X and Y", "is this still current", "verify this claim", "what's the current best practice for".
allowed-tools: Read, Grep, Glob, WebSearch, WebFetch
---

# Research

A structured method for finding out what's actually true before it becomes an architecture or implementation decision — not a request to browse until something plausible turns up.

## Method

1. **Pin down the question.** What exactly needs answering, why it matters to the current task, what decision depends on it.
2. **Check `sources.md`** in this skill folder first — this project's already-vetted sources for its own stack (OpenClaw, NeMo Guardrails, OpenTelemetry, etc.). Don't re-discover what's already catalogued.
3. **Prefer primary sources** — official docs, specs, maintainer repos, papers — over blog summaries and forum posts. Community discussion is fine for practical experience, not as fact.
4. **Establish currency.** Current, deprecated, experimental, widely adopted, vendor-specific, or theoretical. This project sits in fast-moving territory (agentic tooling); don't assume something documented six months ago is still accurate.
5. **Compare real alternatives** on capability, correctness, reliability, scalability, complexity, security, observability, maintainability, cost, performance, ecosystem maturity — not on novelty.
6. **Challenge weak assumptions**, including ones already baked into this project's own docs. State the assumption, the evidence, the problem, the alternatives, the trade-offs, your confidence. Don't quietly go along with something the evidence doesn't support.

## Output format

Use `references/output-template.md` in this skill folder for the exact structure. In short: Research Question → Context → Findings → Current Practice → Alternatives → Trade-offs → Recommendation → Confidence (High/Medium/Low) → Impact on Project → Sources.

## Evidence discipline

- Never invent a source, benchmark, adoption number, or feature claim.
- Label uncertainty; separate fact from interpretation.
- Report disagreement between sources instead of picking one silently.
- If nothing authoritative exists, say that plainly.

## After

If you land on something worth remembering — a verified fact about this project's actual stack, a source worth trusting again — add it to `sources.md` so the next investigation starts further ahead.
