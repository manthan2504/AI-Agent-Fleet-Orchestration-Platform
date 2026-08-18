---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.py"
---

# Coding Conventions

- Minimal, focused diffs. Fix or build what's asked; note anything else, don't fold it in.
- Match existing naming, structure, and error-handling patterns already in the file/module before introducing a new one.
- No hardcoded secrets, keys, tokens, or connection strings — ever, including in comments or example values. Reference the project's existing secrets mechanism.
- Every error path does something meaningful with the error — no silent catch-and-ignore.
- Validate input at any boundary that accepts external or untrusted data.
- New logic gets a test. If you can't add one, say why in the change notes, don't skip silently.
- Async/concurrent by default for anything touching the task queue or worker layer — this project's architecture assumes non-blocking execution there.
- Don't log full prompt contents, credentials, or PII, even for debugging — structured, sanitized events only.
