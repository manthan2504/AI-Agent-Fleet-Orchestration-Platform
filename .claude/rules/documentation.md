# Documentation Standards

- Document *why*, not what the code already says. A comment restating the next line is noise.
- Every non-obvious architectural or technical decision gets a one-line rationale where it's made — not just in an agent's memory file, but where a future reader will actually see it.
- Public interfaces (APIs, component props, task schemas) get their inputs, outputs, and failure behavior documented — not just a name.
- Don't document what's derivable from the code itself (obvious directory layout, a dependency list that's already in package.json). That's what makes docs go stale and get ignored.
- Keep README/setup docs runnable — if a setup step is documented, it should actually work if followed literally, not assume tribal knowledge.
- No secrets, real credentials, or internal URLs in example code or docs, even as "obviously fake" placeholders that look real enough to copy-paste by mistake.
