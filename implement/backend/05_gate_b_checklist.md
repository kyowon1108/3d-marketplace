# BE-05. Gate B Checklist

- Gate: B (Backend)
- Status: `PENDING`

## PASS/FAIL Rules
- PASS: 모든 mandatory 항목 PASS + 증빙 경로 존재
- FAIL: 항목 FAIL 또는 증빙 누락

## Required Templates
1. `templates/evidence_report_template.md`
2. `templates/gate_decision_template.md`

## Checklist
| Item | Status | Evidence Path | Template | Notes |
|---|---|---|---|---|
| `/v1` required endpoints implemented | PENDING | `evidence/backend/YYYY-MM-DD_contract_tests.md` | `templates/evidence_report_template.md` | |
| OpenAPI and runtime contract aligned | PENDING | `evidence/backend/YYYY-MM-DD_openapi_sync.md` | `templates/evidence_report_template.md` | |
| asset status/availability rules verified | PENDING | `evidence/backend/YYYY-MM-DD_asset_state.md` | `templates/evidence_report_template.md` | |
| upload integrity verification works | PENDING | `evidence/backend/YYYY-MM-DD_upload_integrity.md` | `templates/evidence_report_template.md` | |
| idempotency replay no-op works | PENDING | `evidence/backend/YYYY-MM-DD_idempotency.md` | `templates/evidence_report_template.md` | |
| generated type sync complete | PENDING | `evidence/backend/YYYY-MM-DD_type_sync.md` | `templates/evidence_report_template.md` | web + ios |

## Gate Decision
- Current Decision: `NO-GO`
- Decision File: `evidence/backend/YYYY-MM-DD_gate_b_decision.md`
- Template: `templates/gate_decision_template.md`
- Reason: pending items exist
