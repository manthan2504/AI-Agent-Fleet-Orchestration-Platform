---
name: implementation
description: Use when writing or modifying code against a scoped task with clear acceptance criteria — implementing a feature, fixing a bug with a known cause, or making a defined change. Trigger phrases include "implement this", "build this feature", "fix this bug", "add this".
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Implementation

A workflow for turning a scoped task into working, verified code — not a license to also refactor, redesign, or "improve" whatever else is nearby.

## Before writing anything

1. Read the task: acceptance criteria, what it depends on, what's actually in scope.
2. Read the existing code you're about to touch. Don't edit blind off a description of the file.
3. If the task requires a design decision that hasn't been made, that's an `architecture-review`, not something to decide unilaterally mid-implementation.
4. If the task depends on an external library, API, or runtime detail you're not certain is current, that's a `research` task first — especially anything touching the OpenClaw agent runtime, which has a different shape (skills, event subscriptions, action loop) than an SDK-style multi-agent framework. Don't implement against a remembered API shape.

## While implementing

- **Minimal, focused diffs.** Change what the task requires. Note anything else you notice — don't fold it into this change.
- **Match existing conventions** already in the codebase — style, structure, naming, error handling. Check before introducing a new pattern.
- **Build failure handling in.** This project expects retries, timeouts, and structured failure states (transient vs. permanent, tool failure vs. model failure vs. policy rejection) — reflect that where the change touches task execution, not a bare try/catch.
- **Observability isn't optional** where the change touches task, agent, or tool execution — structured events/logs/trace IDs, no secrets or full sensitive prompt content in them.
- **Enforce permissions in code**, not just in a system prompt, anywhere the change touches the Tool Gateway concept.
- **No secrets in code, comments, commits, or logs.** Reference via environment variable or the existing secrets mechanism.

## Before calling it done

- Run the relevant tests. Write them if they don't exist.
- Actually execute the change where feasible — don't just read it and assume it works.
- Re-check the diff against acceptance criteria, line by line.
- If something can't be verified (no test environment, etc.), say so explicitly rather than reporting success you didn't confirm.

## Output format

**Task** — one line.
**Changes Made** — files touched, what changed in each.
**Approach** — and why, if it wasn't the only reasonable option.
**Verification** — what was actually run/checked, and the result.
**Deviations** — anywhere you departed from the literal task or existing pattern, and why.
**Follow-ups / Risks** — anything left undone, any risk introduced, anything worth a second look from review or security.
**Requires Human Approval** — yes/no; if yes, exactly what action and why it's gated.
**Confidence** — High / Medium / Low that this fully satisfies the task.
