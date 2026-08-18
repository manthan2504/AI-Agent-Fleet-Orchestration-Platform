# Security Agent Memory

- [Phase-1 Threat Model](project_threat_model_phase1.md) — the five paths that actually matter for this fleet; injection-via-ingested-content, not perimeter attack.
- [Approval Gate Design Gaps](project_approval_gate_design_gaps.md) — 8 confirmed open gaps in §8.7/§8.7.1 + api.md §11.7 as of 2026-08-18; rejection is retry-eligible.
- [Tool Permission Matrix Gaps](project_tool_permission_matrix_gaps.md) — chained escalation across rows, undifferentiated Filesystem column, unsafe ToolPolicy defaults.
