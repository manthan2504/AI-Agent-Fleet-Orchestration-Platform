# Security Agent Memory

- [Phase-1 Threat Model](project_threat_model_phase1.md) — the five paths that actually matter for this fleet; injection-via-ingested-content, not perimeter attack.
- [Approval Gate Design Gaps](project_approval_gate_design_gaps.md) — 6 of 8 closed by e432107; 5 tracked residuals remain (approver provenance, principal split, params/secret-injection clash).
- [Tool Permission Matrix Gaps](project_tool_permission_matrix_gaps.md) — matrix gaps mostly closed by e432107, but its precedence rule introduced a new High: ALLOW can outrank REQUIRE_APPROVAL.
