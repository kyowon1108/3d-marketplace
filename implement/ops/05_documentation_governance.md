# OPS-05. Documentation Governance

## 1) Source-of-Truth Hierarchy
1. 운영 정책: `ops/03~06*.md`
2. 프로그램 기준: `MASTER_REFACTOR_PLAN.md`
3. 파트 실행 상세: `db/03`, `backend/04`, `ios/03`
4. Gate 판정: `db/04`, `backend/05`, `ios/05`
5. 증빙: `evidence/*`

충돌 시 우선순위:
`ops/* > MASTER > execution_spec > checklist > evidence`

## 2) Architecture Lock (Non-Negotiable)
1. iOS가 모델링을 수행한다.
2. Backend는 파일 ingest/publish/read만 수행한다.
3. Backend GPU 재구성/콜백 파이프라인은 문서/코드 범위에서 제외한다.

## 3) Update Trigger Matrix
| 변경 유형 | 반드시 갱신할 문서/파일 |
|---|---|
| API schema 변경 | `docs/api/openapi.yaml`, `apps/web/lib/api.generated.ts`, `apps/ios/Modules/Networking/ContractEnums.swift`, `apps/ios/Modules/Networking/APIClient.swift`, `backend/01_api_contract_state_machine.md` |
| asset status/availability 규칙 변경 | `backend/01_api_contract_state_machine.md`, `ios/04_web_ios_route_parity_matrix.md`, `backend/05_gate_b_checklist.md`, `ios/05_gate_c_checklist.md` |
| DB migration/constraint 변경 | `db/01_schema_invariants.md`, `db/02_migrations_impact.md`, `db/04_gate_a_checklist.md` |
| 커밋/PR 운영 규칙 변경 | `ops/04_git_commit_pr_workflow.md`, `templates/commit_message_template.md`, `templates/pr_description_template.md` |
| 증빙 포맷 변경 | `evidence/README.md`, `templates/evidence_report_template.md`, 각 gate checklist evidence 경로 |

## 4) Evidence Naming and Storage Rules
1. 파일명: `YYYY-MM-DD_<topic>.md`
2. 위치:
   - DB: `evidence/db/`
   - Backend: `evidence/backend/`
   - iOS: `evidence/ios/`
3. 필수 포함 항목:
   - 실행 명령
   - 결과 요약
   - PASS/FAIL 판정
   - 후속 액션

## 5) Review Ownership and Sign-off
1. Gate A: DB owner sign-off + ops reviewer
2. Gate B: Backend owner sign-off + contract reviewer
3. Gate C: iOS owner sign-off + product parity reviewer
4. 최종 Go/No-Go: `ops/02_refactor_cutover_checklist.md` 반영

## 6) Consistency Rules
1. 체크리스트 항목마다 최소 1개 evidence 링크 필요
2. evidence 링크가 깨지면 해당 항목 자동 FAIL
3. 문서 경로는 상대 경로 기준으로 기록
