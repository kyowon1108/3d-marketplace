# DB-04. Gate A Checklist

- Gate: A (DB)
- Status: `PENDING`

## PASS/FAIL Rules
- PASS: 모든 mandatory 항목이 `PASS`이고 증빙 경로가 존재
- FAIL: 하나라도 `FAIL` 또는 증빙 누락

## Required Templates
1. `templates/evidence_report_template.md`
2. `templates/gate_decision_template.md`

## Checklist
| Item | Status | Evidence Path | Template | Notes |
|---|---|---|---|---|
| migration chain applied | PENDING | `evidence/db/YYYY-MM-DD_migration_apply.md` | `templates/evidence_report_template.md` | |
| Alembic head/current aligned | PENDING | `evidence/db/YYYY-MM-DD_migration_apply.md` | `templates/evidence_report_template.md` | |
| `model_asset_files` constraints/index verified | PENDING | `evidence/db/YYYY-MM-DD_schema_checks.md` | `templates/evidence_report_template.md` | |
| asset status transition rules verified | PENDING | `evidence/db/YYYY-MM-DD_invariants.md` | `templates/evidence_report_template.md` | |
| idempotency key uniqueness verified | PENDING | `evidence/db/YYYY-MM-DD_invariants.md` | `templates/evidence_report_template.md` | |
| checksum/size persistence verified | PENDING | `evidence/db/YYYY-MM-DD_invariants.md` | `templates/evidence_report_template.md` | |
| rollback strategy documented | PENDING | `evidence/db/YYYY-MM-DD_rollforward_strategy.md` | `templates/evidence_report_template.md` | forward-fix 우선 |

## Gate Decision
- Current Decision: `NO-GO`
- Decision File: `evidence/db/YYYY-MM-DD_gate_a_decision.md`
- Template: `templates/gate_decision_template.md`
- Reason: pending items exist
