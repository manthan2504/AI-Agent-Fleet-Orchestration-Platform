# Security Agent Memory

- [Phase-1 Threat Model](project_threat_model_phase1.md) — the five paths that actually matter for this fleet; injection-via-ingested-content, not perimeter attack.
- [Approval Gate Design Gaps](project_approval_gate_design_gaps.md) — all 8 closed as of 0d5de5b; residuals are Medium/Low (approver-config default, rejection durability).
- [Tool Permission Matrix Gaps](project_tool_permission_matrix_gaps.md) — precedence floor added in 0d5de5b closes the High; residual is the floor's classification predicate.
- [Docs-Audit Severity Calibration](feedback_docs_audit_severity_calibration.md) — the line this project's review loop turns on: stated-rule-permits-bypass = High, unspecified-input = Medium.
